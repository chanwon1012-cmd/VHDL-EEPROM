# Phase 2 — 블록 다이어그램 설계

## 시스템 레벨
```
AP Board(TB) ↔ TpgCtrlTop ↔ (SDA/SCL + 외부 풀업) ↔ EEPROM(TB)
```
- `TpgCtrlTop` 안에 기존 `DECODE`/`Module1`/`Module2`(Adder 실습 잔재)와 나란히 `EepRomCtrlTop` 그룹 추가
- `DECODE`에서 `Addr(23:12) = 0x00E` 매칭될 때 `EepRomCtrlTop` 인에이블

## EepRomCtrlTop 내부 계층 (최종 3계층)
```
①I2cBitCtrl(BitCtrl)  →  ②I2cByteCtrl(ByteCtrl)  →  ③I2cMaster
```
- 원래 "①SCL 클럭 분주기"를 별도 블록으로 두려 했으나, `BitCtrl`이 `SysClk` 사이클을 직접 카운트해서 타이밍을 만드는 구조라 **분주기 역할이 BitCtrl에 흡수됨** → 별도 `ClkDivider` 블록 불필요
- 이름 변경: `BitTxRx`→`BitCtrl`, `ByteData_FSM`→`ByteCtrl` (I2cMaster와 이름 체계 통일)

## 계층별 신호 (전부 단방향, 양방향 신호 없음)

| 연결 | 신호 | 방향 |
|---|---|---|
| I2cMaster ↔ ByteCtrl | ByteStart, rw, WriteData[7:0] | I2cMaster → ByteCtrl |
| I2cMaster ↔ ByteCtrl | ByteDone, ACK, ReadData[7:0] | ByteCtrl → I2cMaster |
| I2cMaster ↔ BitCtrl (직결, ByteCtrl 안 거침) | I2cStart, I2cStop | I2cMaster → BitCtrl |
| I2cMaster ↔ BitCtrl (직결) | BitDone | BitCtrl → I2cMaster |
| ByteCtrl ↔ BitCtrl | BitStart, DriveEn | ByteCtrl → BitCtrl |
| ByteCtrl ↔ BitCtrl | BitDone, SdaLatch | BitCtrl → ByteCtrl |
| BitCtrl ↔ 물리 핀 | SdaOut, SdaOe, SclOut | BitCtrl → 외부 |
| BitCtrl ↔ 물리 핀 | SdaIn | 외부 → BitCtrl |

- `I2cStart`/`I2cStop`이 `ByteCtrl`을 건너뛰고 `I2cMaster`↔`BitCtrl` 직결인 이유: START/STOP은 "바이트"가 아니라 BitCtrl이 직접 만드는 특수 버스 조건이라서
- `BitDone`은 한 출력이 `ByteCtrl`과 `I2cMaster` 양쪽에 팬아웃(비트 처리용/START·STOP 완료용, 서로 다른 시점에 사용)
- SDA는 open-drain: `SdaOut`(구동값)/`SdaOe`(구동 인에이블)/`SdaIn`(입력) 3신호로 분리, 최외곽 핀에서만 `sda <= SdaOut when SdaOe='1' else 'Z'`로 합침. 풀업은 `'H'`(weak)로 모델링
- SCL은 클럭 스트레칭 미지원 데이터시트라 마스터 단독 구동 → `SclOut`만 있고 입력 없음

## AP 레지스터 맵 (0x00E)
| 주소 | 레지스터 | 필드 |
|---|---|---|
| 0x001 | REG_ADDR | 15비트 EEPROM 주소 |
| 0x002 | REG_WDATA | 쓸 데이터 8비트 |
| 0x003 | REG_CTRL | `cmd[1:0]`(00=ByteWrite,01=RandomRead,10=CurrentAddrRead), `Start` |
| 0x004 | REG_STATUS | `busy`, `done`, `nack_err` |
| 0x005 | REG_RDATA | 읽은 데이터 8비트 |
