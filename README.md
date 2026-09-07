# FSM_EEPROM

24LC256(32K×8 I2C EEPROM)을 대상으로 하는 **I2C 마스터 컨트롤러 VHDL 설계 실습** 프로젝트입니다. 실제 EEPROM 칩 없이 비헤이비어 모델 기반 테스트벤치로 검증하는 것을 목표로 합니다.

## 목표

- FPGA 실습으로 I2C 마스터 컨트롤러를 VHDL로 설계, 24LC256 EEPROM과 통신
- 최종 목적: EEPROM에 소수의 설정값을 영구 저장하고 전원 재인가 시 복원 (대용량 저장 불필요)
- 대상 디바이스: **Microchip 24LC256** (DS21203C), Industrial 등급, FCLK 400kHz(Fast mode) 기준

## 구현 범위

| 오퍼레이션 | 구현 여부 |
|---|---|
| Byte Write | 구현 대상 |
| Random Read | 구현 대상 |
| Current Address Read | 구현 대상 |
| Page Write (최대 64B) | 보류 — 추후 확장 과제 |
| Sequential Read | 보류 — 추후 확장 과제 |

## 전체 아키텍처

```
AP Board(TB) --IfClk/IfAle/IfWr/IfRd/IfData--> TpgCtrlTop
                                                  ├─ DECODE (주소 디코드, 24bit 주소 래치)
                                                  ├─ Module1 / Module2 (AP I/F 검증용 연산 모듈)
                                                  └─ ClkDivider --SclTick--> EepRomCtrlTop
                                                                              ├─ I2cMaster(FSM)   -- Cmd/Addr/Wdata/Start 수신, Busy/Done/Rdata/Nack_err 응답
                                                                              └─ EEPROM BitTxRx   -- Tx[7:0]/Rx[7:0] <-> SdaIn/SdaOut/SdaOe/SclOut
                                                                                   └─ SDA/SCL (open-drain, Pull-Up) --> EEPROM(TB, 비헤이비어 모델)
```

상세 다이어그램: [참고사항/Total_Block_Diagram.drawio](참고사항/Total_Block_Diagram.drawio), [참고사항/TpgCtrlTop_Block_Diagram.drawio](참고사항/TpgCtrlTop_Block_Diagram.drawio), [참고사항/TB_Block_Diagram.drawio](참고사항/TB_Block_Diagram.drawio)

## 현재 구현 상태

| 블록 | 상태 |
|---|---|
| `TpgCtrlTop` (AP 인터페이스, 주소 디코드) | 구현 완료 — 신호명/배선 오류 수정, `SysClk` 도메인으로의 2FF 동기화(`M1_en_sync`/`M2_en_sync`) 반영 |
| `Module1` / `Module2` (AP I/F 검증용 8-way 합산기) | 구현 완료 — 서로 다른 파이프라인 구조(3단 vs 조합+1단 레지스터)로 동일 기능을 구현해 인터페이스 타이밍 검증용으로 사용 |
| `array_def` (공통 타입 패키지) | 구현 완료 |
| `EepRomCtrlTop` / `I2cMaster(FSM)` / `EEPROM BitTxRx` (실제 I2C EEPROM 제어) | **미구현** — 블록다이어그램 설계만 완료, Phase 0/1 요구사항·데이터시트 분석 완료 |
| EEPROM 비헤이비어 모델 (TB) | 미구현 |

즉, 현재 `source/`의 `TpgCtrlTop`+`Module1`+`Module2`는 AP 인터페이스(주소 래치, R/W 디스패치, 클럭 도메인 동기화)를 먼저 검증하기 위한 골격이며, 실제 24LC256 I2C 프로토콜 FSM은 다음 단계에서 이 골격에 통합될 예정입니다.

## 디렉터리 구조

```
source/                  VHDL 소스
├─ array_def.vhd         공용 배열 타입 패키지 (std_logic_bit2 ~ bit64)
├─ TpgCtrlTop.vhd         Top: AP 인터페이스 + 주소 디코드 + 서브모듈 연결
├─ Module1.vhd            AP I/F 검증용 8-way 합산기 (3단 파이프라인)
└─ Module2.vhd            AP I/F 검증용 8-way 합산기 (조합 합산 + 1단 레지스터)

참고사항/                 요구사항 정리, 데이터시트 스터디, 설계 다이어그램, 체크리스트
```

## 참고 문서 (참고사항/)

| 파일 | 내용 |
|---|---|
| `Phase0_요구사항_정의.md` | 프로젝트 목표, 구현 범위, 커맨드 인터페이스 초안, 검증 방식 확정 |
| `Phase1_데이터시트_스터디.md` | 24AA256/24LC256 AC 특성, 버스 규약, 주소 지정, Byte Write, ACK Polling, Read 오퍼레이션 3종 정리 |
| `24AA256.PDF` | 24AA256/24LC256 데이터시트 (DS21203C) |
| `24LC256_체크리스트_1.xlsx` | 구현/검증 체크리스트 |
| `BitChart.xlsx` | 비트 단위 신호 구성 정리 |
| `SysClk_Timing_Calc.xlsx` | 시스템 클럭 대비 I2C 타이밍(분주비 등) 계산 |
| `TimingChart.xlsx` | I2C 타이밍 차트 |
| `Total_Block_Diagram.drawio` | 전체 시스템 블록 다이어그램 (AP Board ~ EEPROM) |
| `TpgCtrlTop_Block_Diagram.drawio` | `TpgCtrlTop` 내부 블록 다이어그램 |
| `TB_Block_Diagram.drawio` | 테스트벤치 구성 다이어그램 |

## 남은 작업 (TODO)

- [ ] 목표 클럭 속도(100kHz vs 400kHz) 및 `SysClk` 대비 분주비 확정
- [ ] `I2cMaster`(I2C 프로토콜 FSM) 구현 — Byte Write / Random Read / Current Address Read, ACK Polling 포함
- [ ] `EEPROM BitTxRx`(SDA/SCL 비트 송수신) 구현
- [ ] `ClkDivider`(`SclTick` 생성) 구현
- [ ] EEPROM 비헤이비어 모델(TB) 구현
- [ ] `EepRomCtrlTop`을 `TpgCtrlTop`에 통합
