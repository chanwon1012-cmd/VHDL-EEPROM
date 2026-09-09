
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

ENTITY BitCtrl IS
    GENERIC (
        T_LOW    : INTEGER := 65;
        T_SETUP  : INTEGER := 5;
        T_HIGH   : INTEGER := 30;
        T_HD_STA : INTEGER := 30;
        T_SU_STO : INTEGER := 30
    );
    PORT (
        SysClk : IN STD_LOGIC;
        nRST   : IN STD_LOGIC;

        BitStart : IN STD_LOGIC;
        I2cStart : IN STD_LOGIC;
        I2cStop  : IN STD_LOGIC;
        DriveEn  : IN STD_LOGIC;
        TxBit    : IN STD_LOGIC;
        SdaIn    : IN STD_LOGIC;

        SclOut   : OUT STD_LOGIC;
        SdaOe    : OUT STD_LOGIC;
        SdaOut   : OUT STD_LOGIC;
        BitDone  : OUT STD_LOGIC;
        SdaLatch : OUT STD_LOGIC
    );
END BitCtrl;

ARCHITECTURE Behavioral OF BitCtrl IS
    TYPE State IS (IDLE, GEN_START, GEN_STOP, SCL_LOW, SDA_SETUP, SCL_HIGH);
    SIGNAL StateC, StateN : State;
    SIGNAL Cnt            : INTEGER RANGE 0 TO 127; -- 2^7, min -> T_LOW(65)

BEGIN
    --Counter
    PROCESS (SysClk, nRST)
    BEGIN
        IF nRST = '0' THEN
            Cnt <= 0;
        ELSIF rising_edge(SysClk) THEN
            IF StateN /= StateC THEN
                Cnt <= 0;
            ELSE
                Cnt <= Cnt + 1;
            END IF;
        END IF;
    END PROCESS;

    --seq
    PROCESS (SysClk, nRST)
    BEGIN
        IF nRST = '0' THEN
            StateC <= IDLE;
        ELSIF rising_edge(SysClk) THEN
            StateC <= StateN;
        END IF;
    END PROCESS;

    -- comb
    PROCESS (ALL)
    BEGIN
        StateN   <= StateC;
        SclOut   <= '0';
        SdaOe    <= '0';
        SdaOut   <= '0';
        BitDone  <= '0';
        SdaLatch <= '0';

        CASE(StateC) IS

            WHEN IDLE =>
            SclOut <= '1';
            IF BitStart = '1' THEN
                StateN <= SCL_LOW;
            ELSIF I2cStart = '1' THEN
                StateN <= GEN_START;
            ELSIF I2cStop = '1' THEN
                StateN <= GEN_STOP;
            ELSE
                StateN <= IDLE;
            END IF;

            WHEN SCL_LOW =>
            SdaOe  <= DriveEn;
            SdaOut <= TxBit;
            IF Cnt = T_LOW THEN
                StateN <= SDA_SETUP;
            ELSE
                StateN <= SCL_LOW;
            END IF;

            WHEN SDA_SETUP =>
            SdaOe  <= DriveEn;
            SdaOut <= TxBit;
            IF Cnt = T_SETUP THEN
                StateN <= SCL_HIGH;
            ELSE
                StateN <= SDA_SETUP;
            END IF;

            WHEN SCL_HIGH =>
            SclOut <= '1';
            SdaOe  <= DriveEn;
            SdaOut <= TxBit;
            IF Cnt = T_HIGH THEN
                StateN   <= IDLE;
                BitDone  <= '1';
                SdaLatch <= SdaIn;
            ELSE
                StateN <= SCL_HIGH;
            END IF;

            WHEN GEN_START =>
            SclOut <= '1';
            IF Cnt = T_HD_STA THEN
                StateN  <= IDLE;
                SdaOe   <= '1';
                SdaOut  <= '0';
                BitDone <= '1';
            ELSE
                SdaOe  <= '1';
                SdaOut <= '0';
            END IF;

            WHEN GEN_STOP =>
            SclOut <= '1';
            IF Cnt = T_SU_STO THEN
                StateN  <= IDLE;
                SdaOe   <= '0';
                SdaOut  <= '1';
                BitDone <= '1';
            ELSE
                SdaOe  <= '0';
                SdaOut <= '1';
            END IF;
            WHEN OTHERS => StateN <= IDLE;
        END CASE;
    END PROCESS;
END Behavioral;