# Phase 3 — 비트 / 타이밍 차트

## 구현 대상 3종 파형

**Byte Write**
```
START → 컨트롤바이트(0xA0,Write) → ACK → 주소상위 → ACK → 주소하위 → ACK → 데이터 → ACK → STOP
```
- 전 구간 Master가 밈(드라이브), ACK 비트만 Slave가 밈

**Random Read**
```
START → 컨트롤바이트(0xA0,Write) → ACK → 주소상위 → ACK → 주소하위 → ACK
  → Repeated START → 컨트롤바이트(0xA1,Read) → ACK → 데이터(Slave가 밈) → 마스터 NACK → STOP
```

**Current Address Read**
```
START → 컨트롤바이트(0xA1,Read) → ACK → 데이터(Slave가 밈) → 마스터 NACK → STOP
```
- 주소 세팅 단계 전부 생략 (EEPROM 내부 주소 포인터 그대로 사용)
- ⚠️ 초기 설계 때 실수로 컨트롤바이트(Write,0xA0)를 먼저 보내던 버그가 있었음 → cmd 분기를 START 직후(컨트롤바이트 전송 전)로 옮겨서 수정

## 컨트롤바이트 방향 규칙 (BitCtrl/ByteCtrl 설계의 기반)
| 상태 | Write일 때 | Read일 때 |
|---|---|---|
| 데이터 8비트 | Master가 밈 (`DriveEn=1`) | Slave가 밈, Master는 놓음 (`DriveEn=0`) |
| 9th(ACK/NACK) | Slave가 밈, Master는 놓음 (`DriveEn=0`) | Master가 밈 (`DriveEn=1`) |

## SysClk 타이밍 계산 (SysClk_Timing_Calc.xlsx)
- 채택 SysClk: **50MHz (20ns 주기)**
- 데이터시트 AC 특성(Industrial/2.5-5.5V/400kHz 기준) → SysClk 클럭 수로 환산 완료:

| 파라미터 | 최소값(ns) | 쓰이는 곳 |
|---|---|---|
| THIGH | 600 | BitCtrl SCL_HIGH 유지 클럭 수 |
| TLOW | 1300 | BitCtrl SCL_LOW 유지 클럭 수 |
| THD:STA | 600 | BitCtrl GEN_START 유지 클럭 수 |
| TSU:STA | 600 | Repeated START 전 대기 (I2cMaster REP_START) |
| TSU:DAT | 100 | BitCtrl SDA_SETUP 유지 클럭 수 |
| THD:DAT | 0 | 별도 대기 불필요 |
| TSU:STO | 600 | BitCtrl GEN_STOP 유지 클럭 수 |
| TBUF | 1300 | 트랜잭션 간 최소 간격 (참고용, 현재 설계엔 미반영) |

- TR/TF/TAA/TWC(5ms)는 FSM 카운터에 직접 안 쓰임 (TWC는 필요시 ACK Polling으로 대응, 이번 설계에선 미구현)

## 비트 차트 (I2C_BitChart_Template.xlsx)
- ByteWrite/RandomRead 시트에 구간별 실제값(hex)/미는쪽/Bit7~0/9th(ACK) 채움 완료
- 예: 컨트롤바이트(Write) `1010 0000`=`0xA0`, 컨트롤바이트(Read) `1010 0001`=`0xA1`
