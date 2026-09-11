
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

USE work.array_def.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY ByteCtrl IS
    PORT (
        -- Input
        -- System
        SysClk : IN STD_LOGIC;
        nRST   : IN STD_LOGIC;
        -- I2c
        ByteStart : IN STD_LOGIC;
        rw        : IN STD_LOGIC;
        WriteData : IN STD_LOGIC_VECTOR (7 DOWNTO 0);
        -- BitCtrl
        BitDone  : IN STD_LOGIC;
        SdaLatch : IN STD_LOGIC;

        -- Output
        -- I2c
        ByteDone : OUT STD_LOGIC;
        ReadData : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
        Ack      : OUT STD_LOGIC;
        -- BitCtrl
        TxBit    : OUT STD_LOGIC;
        BitStart : OUT STD_LOGIC;
        DriveEn  : OUT STD_LOGIC
    );
END ByteCtrl;

ARCHITECTURE Behavioral OF ByteCtrl IS
    TYPE State IS (IDLE, LOAD, SHIFT_BIT, ACK_CHECK, DONE);
    SIGNAL StateC, StateN : State;
    SIGNAL DataReg        : STD_LOGIC_VECTOR (7 DOWNTO 0);
    SIGNAL Cnt            : INTEGER RANGE 0 TO 7;

BEGIN
    -- Counter
    PROCESS (SysClk, nRST)
    BEGIN
        IF nRST = '0' THEN
            Cnt <= 7;
        ELSIF Rising_edge(SysClk) THEN
            IF StateC /= StateN THEN
                Cnt <= 7;
            ELSIF BitDone = '1' THEN
                Cnt <= Cnt - 1;
            END IF;
        END IF;
    END PROCESS;

    -- S Logic
    PROCESS (SysClk, nRST)
    BEGIN
        IF nRST = '0' THEN
            StateC <= IDLE;
        ELSIF rising_edge(SysClk) THEN
            StateC <= StateN;
        END IF;
    END PROCESS;

    -- C Logic
    PROCESS (StateC, rw, WriteData, SdaLatch, DataReg, ByteStart, BitDone, Cnt)
    BEGIN
        StateN   <= StateC;
        ByteDone <= '0';
        ReadData <= (others => '0');
        Ack      <= '0';
        TxBit    <= '0';
        BitStart <= '0';
        DriveEn  <= '0';

        CASE(StateC) IS

            WHEN IDLE =>
            IF ByteStart = '1' THEN
                StateN <= LOAD;
            ELSE
                StateN <= IDLE;
            END IF;

            WHEN LOAD =>
            Bitstart <= '1';
            DriveEn  <= NOT rw;
            DataReg  <= WriteData;
            txBit    <= WriteData(7);

            WHEN SHIFT_BIT =>
            IF Cnt = 0 AND BitDone = '1' THEN
                BitStart <= '1';
                DataReg  <= DataReg(6 DOWNTO 0) & SdaLatch;
                TxBit    <= DataReg(6);
                DriveEn  <= rw;
                StateN   <= ACK_CHECK;
            ELSIF BitDone = '0' THEN
                StateN <= SHIFT_BIT;
            ELSE
                BitStart <= '1';
                DataReg  <= DataReg(6 DOWNTO 0) & SdaLatch;
                TxBit    <= DataReg(6);
                StateN   <= SHIFT_BIT;
            END IF;

            WHEN ACK_CHECK =>
            IF BitDone = '1' THEN
                ACK    <= SdaLatch;
                StateN <= DONE;
            ELSE
                StateN <= ACK_CHECK;
            END IF;

            WHEN DONE =>
            ByteDone <= '1';
            ReadData <= DataReg;
            StateN   <= IDLE;

            WHEN OTHERS => StateN <= IDLE;

        END CASE;
    END PROCESS;
END Behavioral;