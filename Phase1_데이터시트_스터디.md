# Phase 1 — 데이터시트 스터디 정리 (24AA256/24LC256, DS21203C)

동작 조건: **Industrial(I) 등급, 2.5V ≤ VCC ≤ 5.5V, FCLK = 400kHz (Fast mode)**

## 1. AC Characteristics (Table 1-3)

위 조건에서 확정된 타이밍 값:

| 파라미터 | 기호 | 값 | 용도 |
|---|---|---|---|
| Clock high time | THIGH | ≥ 600 ns | SCL High 최소 유지시간 |
| Clock low time | TLOW | ≥ 1300 ns | SCL Low 최소 유지시간 (분주 카운터 기준값) |
| SDA/SCL rise time | TR | ≤ 300 ns | 버스 라인 특성 |
| SDA/SCL fall time | TF | ≤ 300 ns | 버스 라인 특성 |
| START hold time | THD:STA | ≥ 600 ns | START 직후 첫 SCL Low까지 대기시간 |
| START setup time | TSU:STA | ≥ 600 ns | (Repeated) START 전 SDA High 유지시간 |
| Data setup time | TSU:DAT | ≥ 100 ns | SDA 변경 후 SCL rising까지 여유 |
| Data hold time | THD:DAT | ≥ 0 ns | SCL falling 후 SDA 변경까지 여유 |
| STOP setup time | TSU:STO | ≥ 600 ns | STOP 전 SCL High 유지시간 |
| Bus free time | TBUF | ≥ 1300 ns | STOP ~ 다음 START 사이 최소 간격 |
| Output valid from clock | TAA | ≤ 900 ns | Read 시 SCL 이후 데이터 유효 시점 |
| Write cycle time | TWC | ≤ 5 ms | 내부 쓰기 사이클 완료 대기 (ACK Polling 대상) |

## 2. 버스 기본 규칙 (Figure 4-1, 4-2)

**4가지 기본 상태 (Figure 4-1):**

| 상태 | 조건 |
|---|---|
| Bus not Busy | SDA, SCL 둘 다 HIGH |
| START | SCL=HIGH인 동안 SDA가 HIGH→LOW |
| STOP | SCL=HIGH인 동안 SDA가 LOW→HIGH |
| Data Valid | SCL=HIGH 동안 SDA는 안정 유지 — **SDA는 SCL Low일 때만 변경 가능** |

**ACK 구조 (Figure 4-2):** 바이트 하나 전송 = **SCL 9클럭** (데이터 8비트 + ACK 1비트)
- 8비트 다 보낸 쪽이 9번째 클럭에서 **SDA를 release**
- **받는 쪽(리시버)**이 그 클럭 동안 SDA를 LOW로 끌면 ACK, 안 끌면(HIGH 유지) NACK
- Write 시: 슬레이브가 ACK / Read 시: 마스터가 ACK(계속) 또는 NACK(종료)

## 3. Device Addressing (Figure 5-1, 5-2)

**컨트롤 바이트 (Figure 5-1):**
```
S | 1 0 1 0 | A2 A1 A0 | R/W̄ | ACK
```
- `1010`: 고정 Control Code
- `A2A1A0`: Chip Select (본 프로젝트는 `000` 가정, 보드 미확정)
- `R/W̄`: 1=Read, 0=Write

| 오퍼레이션 | 컨트롤 바이트 값 |
|---|---|
| Write | `1010 000 0` = **0xA0** |
| Read | `1010 000 1` = **0xA1** |

**주소 구조 (Figure 5-2):** 2바이트, A14~A0(15비트) 유효
```
ADDRESS HIGH = X, A14, A13, ..., A8   (X=don't care)
ADDRESS LOW  = A7, A6, ..., A0
```
15비트 = 2^15 = 32768 = 32K → 24LC256(32K×8) 전체 공간 커버. High 바이트 먼저 전송.

## 4. Byte Write (Figure 6-1)

```
START → 컨트롤바이트(0xA0)+ACK → 주소상위+ACK → 주소하위+ACK → 데이터+ACK → STOP
```
- 바이트 4개 × 9클럭 = 36클럭 (+START/STOP)
- **WP 핀**: STOP 시점에 샘플링. `WP=VCC`면 ACK는 하지만 실제 쓰기는 안 일어남. 본 프로젝트는 WP 미사용(플로팅=쓰기 허용) 가정
- STOP 이후 내부 주소 포인터가 자동으로 다음 주소로 증가

## 5. 내부 쓰기 사이클 & ACK Polling (Figure 7-1)

**내부 쓰기 사이클이란**: STOP을 받은 뒤, 칩이 I2C와 무관하게 **자체적으로(self-timed)** 받은 데이터를 EEPROM 셀에 물리적으로 새겨 넣는(erase+program) 과정. 최대 5ms(TWC) 소요되며, 이 동안 칩은 어떤 I2C 커맨드에도 ACK하지 않음.

**ACK Polling 플로우:**
```
Write 커맨드 + STOP (내부 쓰기 사이클 시작)
   ↓
┌→ START → 컨트롤바이트(R/W̄=0, 프로브용) → ACK 왔나?
│         NO(NACK, 아직 쓰기 중) ─┘ (재시도)
└─ YES(ACK, 쓰기 완료) → 다음 오퍼레이션 진행
```
- 프로브는 항상 R/W̄=0(Write)으로 보냄 (다음이 Read든 Write든 무관하게 "완료됐나?"만 확인)
- 목적: 매번 5ms 무조건 대기하지 않고 실제 완료 시점을 빠르게 감지 → 버스 처리량 향상

## 6. Read 오퍼레이션 3종 (Figure 8-1, 8-2, 8-3)

| | 시퀀스 | 구현 여부 |
|---|---|---|
| **Current Address Read** | `START → 0xA1+ACK → DATA → NACK(마스터) → STOP` | 구현 |
| **Random Read** | `START → 0xA0+ACK → 주소상위+ACK → 주소하위+ACK → ★Repeated START★ → 0xA1+ACK → DATA → NACK(마스터) → STOP` | 구현 |
| **Sequential Read** | Random Read와 동일하게 시작, 이후 각 DATA마다 마스터가 **ACK("더줘")** 반복, 마지막 바이트에서만 **NACK("그만")** → STOP | 보류(참고만) |

- **Random Read가 Repeated START가 필요한 이유**: 주소를 세팅하는 과정(Write 형식)과 실제 읽는 과정(Read 형식) 사이에 STOP으로 버스를 놓아버리면 안 되고, 버스 소유권을 유지한 채 방향만 전환해야 하기 때문
- **Sequential Read 종료가 마스터 NACK인 이유**: 마스터가 ACK를 하면 슬레이브는 계속 다음 주소 데이터를 보내려 하므로, 마지막으로 받고 싶은 바이트에서 일부러 NACK를 줘야 슬레이브가 전송을 멈춤
- 주소 포인터는 0x7FFF에서 0x0000으로 롤오버

## 7. `cmd`별 FSM 경로 요약 (실제 구현 대상)

| `cmd` | 오퍼레이션 | 시퀀스 |
|---|---|---|
| `00` | Byte Write | START→CTRL(0xA0)+ACK→ADDR_H+ACK→ADDR_L+ACK→DATA+ACK→STOP |
| `01` | Random Read | START→CTRL(0xA0)+ACK→ADDR_H+ACK→ADDR_L+ACK→**REP_START**→CTRL(0xA1)+ACK→DATA→NACK→STOP |
| `10` | Current Address Read | START→CTRL(0xA1)+ACK→DATA→NACK→STOP |

## 8. 남은 항목

- Table 1-1 핀 기능(SDA/SCL/A0~A2/WP) 정식 리뷰는 아직 안 함 (WP의 쓰기보호 동작은 6.3절에서 부분적으로 확인됨)
- Figure 6-2 Page Write, Figure 8-3 Sequential Read는 데이터시트 스터디만 완료, **구현 범위에서는 제외**
