# Phase 0 — 요구사항 정의 정리

24LC256 EEPROM용 I2C 마스터 컨트롤러 (FSM 실습) 프로젝트의 요구사항 정의 단계 정리.

## 1. 프로젝트 목표

FPGA 실습으로 I2C 마스터 컨트롤러를 VHDL로 설계해서 24LC256 EEPROM과 통신한다. 실제 EEPROM 칩이 없어서 테스트벤치(비헤이비어 모델)로 검증한다. 최종 목적은 EEPROM에 소수의 설정값을 영구 저장하고 전원 재인가 시 복원하는 것 — 대용량 데이터 저장이 아니므로 DRAM은 불필요하다고 결론.

## 2. 구현 범위 확정

**Byte Write + Random Read + Current Address Read**, 이 3가지만 구현한다.

| 오퍼레이션 | 구현 여부 |
|---|---|
| Byte Write | 구현 |
| Random Read | 구현 |
| Current Address Read | 구현 |
| Page Write (최대 64B) | 보류 — 추후 확장 과제 |
| Sequential Read | 보류 — 추후 확장 과제 |

## 3. 상위 유저 로직 커맨드 인터페이스 초안

`Eep24AA256`(I2C 프로토콜 FSM)이 상위 로직에 제공할 커맨드 인터페이스 초안:

| 신호 | 방향 | 설명 |
|---|---|---|
| `cmd[1:0]` | in | `00`=Byte Write, `01`=Random Read, `10`=Current Address Read |
| `addr[14:0]` | in | EEPROM 내부 주소 (A14~A0) |
| `wdata[7:0]` | in | 쓸 데이터 |
| `start` | in | busy=0일 때 1클럭 펄스로 트랜잭션 시작 |
| `busy` | out | 트랜잭션 진행 중 |
| `done` | out | 트랜잭션 종료 시 1클럭 (busy=0과 동시) |
| `rdata[7:0]` | out | 읽은 데이터 (다음 start 전까지 유지) |
| `nack_err` | out | 슬레이브 NACK 에러 (다음 start 전까지 유지) |

**핸드셰이크 규칙:**
- `busy=0`일 때 `addr`/`wdata`/`cmd`를 세팅한 뒤 `start` 1클럭 펄스
- `busy` 동안 재진입(`start`) 무시
- 트랜잭션 종료 시 `busy=0`·`done=1` 동시 발생, `rdata`/`nack_err`는 다음 `start` 전까지 유지

## 4. 대상 디바이스 확정

- **Microchip 24LC256** (32K×8 I2C EEPROM), 데이터시트 DS21203C
- Vcc 2.5~5.5V (산업용 등급), FCLK 최대 400kHz, SDA/SCL rise time(TR) 최대 300ns
  - TR/FCLK는 Vcc·온도등급 조건에 세트로 묶여 결정됨 — 100kHz로 운용해도 TR 조건(300ns)은 완화되지 않음
- 슬레이브 주소: `1010`(I2C 직렬 EEPROM 공통 고정 코드) + `A2A1A0`(칩 셀렉트, 보드 미확정이라 일단 `000` 가정)
- 클럭 스트레칭 미지원 → SCL은 마스터가 단독 구동해도 됨

## 5. 검증 방식 확정

실칩이 없으므로 **TB 비헤이비어 모델 기반 시뮬레이션 검증**으로 진행한다.

- **AP 자극**: 기존에 쓰던 메모장 기반 `P 주소 W 데이터` / `R 주소` 커맨드 파일 방식을 그대로 재사용 (새 문법 불필요)
- **EEPROM 응답**: 별도 비헤이비어 모델(VHDL)로 구현 예정

## 미확정 항목 (Phase 0 잔여)

- **목표 클럭 속도** — 100kHz(Standard) vs 400kHz(Fast) 중 선택 및 FPGA 시스템 클럭 대비 분주 가능 여부 확인은 아직 미결정
