# Phase 4 — FSM 설계 (BitCtrl / ByteCtrl / I2cMaster)

3계층 FSM. 아래 표가 그대로 Phase 5 VHDL `case state is when ... =>`로 옮겨질 스펙임.

---

## ① I2cBitCtrl (BitCtrl) — 비트/START/STOP 물리 파형 생성

입력: `DriveEn`, `SdaIn`, `BitStart`, `I2cStart`, `I2cStop` / 출력: `SdaOe`, `SclOut`, `SdaLatch`, `BitDone`

| 현재 상태 | 입력조건 | 다음상태 | 출력 |
|---|---|---|---|
| WAIT | BitStart==1 | SCL_LOW | Scl=1 |
| WAIT | I2cStart==1 | GEN_START | Scl=1 |
| WAIT | I2cStop==1 | GEN_STOP | Scl=1 |
| SCL_LOW | counter==tLow | SDA_SETUP | Scl=0, SdaOe=DriveEn |
| SCL_LOW | counter<tLow | SCL_LOW | Scl=0, SdaOe=DriveEn |
| SDA_SETUP | counter==tsu(Data) | SCL_HIGH | Scl=0, SdaOe=DriveEn |
| SDA_SETUP | counter<tsu(Data) | SDA_SETUP | Scl=0, SdaOe=DriveEn |
| SCL_HIGH | counter==thigh | WAIT | Scl=1, SdaOe=DriveEn, BitDone=1, SdaLatch=SdaIn |
| SCL_HIGH | counter<thigh | SCL_HIGH | Scl=1, SdaOe=DriveEn |
| GEN_START | counter==tHD:STA | WAIT | Scl=1, SdaOe=1, Sda=0, BitDone=1 |
| GEN_START | counter<tHD:STA | GEN_START | Scl=1, SdaOe=1, Sda=0 |
| GEN_STOP | counter==tSU:STO | WAIT | Scl=1, SdaOe=0, Sda=1, BitDone=1 |
| GEN_STOP | counter<tSU:STO | GEN_STOP | Scl=1, SdaOe=0, Sda=1 |

- 비트 하나 처리 중 `SdaOe`는 3상태(SCL_LOW/SDA_SETUP/SCL_HIGH) 내내 `DriveEn` 값으로 고정 유지
- `SCL_HIGH` 종료 후 무한루프 대신 `WAIT`로 복귀 → 다음 트리거(BitStart/I2cStart/I2cStop) 대기
- `GEN_START`: SDA 1→0 (직접 구동), `GEN_STOP`: SDA 0→1 (풀업에 맡김, SdaOe=0)
- (선택, 미반영) `Scl` 값은 SCL_LOW/SDA_SETUP일 때만 0이고 나머지 전부 1 — 표에 명시했으나 RTL에서 실제 반영 필요

---

## ② I2cByteCtrl (ByteCtrl) — 8비트 시프트 + ACK 체크

입력: `ByteStart`, `rw`, `WriteData[7:0]`, `BitDone`, `SdaLatch` / 출력: `BitStart`, `DriveEn`, `ByteDone`, `ACK`, `ReadData[7:0]`

| 현재 상태 | 입력조건 | 다음상태 | 출력 |
|---|---|---|---|
| WAIT | ByteStart==1 | LOAD | |
| WAIT | ByteStart==0 | WAIT | |
| LOAD | (자동) | SHIFT_BIT | BitCount=7, BitStart=1, DriveEn=(rw==Write?1:0), reg=WriteData |
| SHIFT_BIT | BitDone==0 | SHIFT_BIT | |
| SHIFT_BIT | BitCount>0, BitDone==1 | SHIFT_BIT | BitStart=1, reg=reg[6:0]&SdaLatch, BitCount-1 |
| SHIFT_BIT | BitCount==0, BitDone==1 | ACK_CHECK | BitStart=1, reg=reg[6:0]&SdaLatch, BitCount-1, DriveEn=(rw==Write?0:1) |
| ACK_CHECK | BitDone==0 | ACK_CHECK | |
| ACK_CHECK | BitDone==1 | DONE | ACK=SdaLatch |
| DONE | (자동) | WAIT | ByteDone=1, ReadData=reg |

- `BitCount` 초기값 7 + 종료조건 `==0`(디코딩 시 실질 8비트) — off-by-one 버그 두 차례 수정 후 확정
- `BitStart`/`DriveEn`은 "새 비트를 실제로 킥오프하는 줄"에만 존재 (대기 줄엔 없음) — 안 그러면 매 클럭 재트리거되는 버그
- `reg=reg[6:0]&SdaLatch`로 통일: Write는 시프트인 값이 버려져 무해, Read는 실제 수신값이 채워짐
- `ACK_CHECK`의 `DriveEn`은 `SHIFT_BIT`와 반대 (Write→0, Read→1): ACK 비트는 데이터와 방향이 뒤집힘

---

## ③ I2cMaster — 최상위 커맨드 FSM

입력: `Start`, `cmd[1:0]`, `Addr[14:0]`, `WData[7:0]`, `ACK`, `ByteDone`, `BitDone` / 출력: `busy`, `done`, `nack_err`, `Rdata[7:0]`, `I2cStart`, `I2cStop`, `ByteStart`, `rw`, `WriteData`

| 현재 상태 | 입력조건 | 다음상태 | 출력 |
|---|---|---|---|
| IDLE | Start==1 | START | busy=0 |
| IDLE | Start==0 | IDLE | busy=0 |
| START | BitDone==1 | CTRL_BYTE | busy=1, I2cStart=1 |
| CTRL_BYTE | cmd==2 | CTRL_BYTE_R | busy=1, WriteData=0xA0 |
| CTRL_BYTE | cmd==0 or 1, ByteDone==1, ACK==1 | ADDR_H | busy=1, WriteData=0xA0 |
| ADDR_H | ACK==1, ByteDone==1 | ADDR_L | busy=1, WriteData=Addr[14:8] |
| ADDR_L | ACK==1, cmd==0, ByteDone==1 | DATA | busy=1, WriteData=Addr[7:0] |
| ADDR_L | ACK==1, cmd==1, ByteDone==1 | REP_START | busy=1, WriteData=Addr[7:0] |
| DATA | ACK==1, ByteDone==1 | STOP | busy=1, WriteData=WData |
| REP_START | BitDone==1 | CTRL_BYTE_R | busy=1, I2cStart=1 |
| CTRL_BYTE_R | ACK==1, ByteDone==1 | READ_DATA | busy=1, WriteData=0xA1 |
| READ_DATA | ACK==1, ByteDone==1 | STOP | busy=1, Rdata=ReadData |
| STOP | BitDone==1 | IDLE | busy=0, done=1, I2cStop=1 |
| CTRL_BYTE / ADDR_H / ADDR_L / DATA / CTRL_BYTE_R / READ_DATA | **ACK==0**, ByteDone==1 (6곳 전부) | STOP | busy=1, nack_err=1 |

- `cmd`: `00`=Byte Write, `01`=Random Read, `10`=Current Address Read
- `cmd==2` 분기를 `CTRL_BYTE` **진입 직후** 두어 Current Address Read가 컨트롤바이트(Write,0xA0)를 아예 안 보내도록 함 (초기 버그 수정됨)
- `CTRL_BYTE_R`(0xA1 컨트롤바이트)은 Random Read(REP_START 경유)와 Current Address Read(cmd==2 직행) 양쪽에서 공유
- `START`/`REP_START`/`STOP`은 `ByteCtrl`을 안 거치고 `BitCtrl`에 직접 `I2cStart`/`I2cStop` 요청 + `BitDone` 대기
- NACK(ACK==0) 시 재시도 없이 6개 상태 전부 동일하게 `STOP`+`nack_err=1`로 단순 에러 리턴 (ACK Polling 등 재시도 로직은 이번 설계 범위 밖)

---

## 남은 선택 항목 (RTL 진행에 지장 없음)
- I2cMaster 다이어그램(화살표)에 NACK 6곳 실제로 그려서 표와 시각적 동기화
- BitTxRx/I2cMaster의 `Scl` 출력 값을 표에 명시 (동작 자체는 이미 맞음)
- 파일/블록 구버전 잔재 정리 (`TpgCtrlTop_Block_Diagram.drawio`의 미사용 "EEPROM BitTxRx" 박스 등)
