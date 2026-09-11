LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

USE work.array_def.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY I2cMaster IS
    PORT (
        -- System
        SysClk : IN STD_LOGIC;
        nRST   : IN STD_LOGIC;

        -- TpgCtrlTop
        Cmd      : IN STD_LOGIC_VECTOR (1 DOWNTO 0);
        Addr     : IN STD_LOGIC_VECTOR (14 DOWNTO 0);
        Run      : IN STD_LOGIC;
        Wdata    : IN STD_LOGIC_VECTOR (7 DOWNTO 0);
        Busy     : OUT STD_LOGIC;
        Done     : OUT STD_LOGIC;
        Rdata    : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
        Nack_err : OUT STD_LOGIC;

        -- Eeprom
        SdaInIN : IN STD_LOGIC;
        SclOut  : OUT STD_LOGIC;
        SdaOut  : OUT STD_LOGIC;
        SdaOe   : OUT STD_LOGIC
    );
END I2cMaster;

ARCHITECTURE Behavioral OF I2cMaster IS

    TYPE State IS (IDLE, START, CTRL_BYTE, ADDR_H, ADDR_L, DATA, STOP, REP_START, CTRL_BYTE_R, READ_DATA);
    SIGNAL StateC, StateN : State;

    SIGNAL BitStart  : STD_LOGIC;
    SIGNAL Bitdone   : STD_LOGIC;
    SIGNAL I2cStart  : STD_LOGIC;
    SIGNAL I2cStop   : STD_LOGIC;
    SIGNAL ByteDone  : STD_LOGIC;
    SIGNAL WriteData : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL ReadData  : STD_LOGIC_VECTOR(7 DOWNTO 0);

    COMPONENT BitCtrl IS
        GENERIC (
            T_LOW    : INTEGER := 90;
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
    END COMPONENT;

    COMPONENT ByteCtrl IS
        PORT (
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
    END COMPONENT;

BEGIN

    BitCtrl_Inst : BitCtrl
    GENERIC MAP(
        generics
    )
    PORT MAP(
        SysClk   => SysClk,
        nRST     => nRST,
        BitStart => BitStart,
        I2cStart => I2cStart,
        I2cStop  => I2cStop,
        DriveEn  => DriveEn,
        TxBit    => TxBit,
        SdaIn    =>
        SclOut   =>
        SdaOe    =>
        SdaOut   =>
        BitDone  => Bitdone
        SdaLatch => SdaLatch
    );

    ByteCtrl_Inst : ByteCtrl
    PORT MAP(
        SysClk    => SysClk,
        nRST      => nRST,
        ByteStart =>
        rw        =>
        WriteData => WriteData
        BitDone   => BitDone,
        SdaLatch  => SdaLatch,
        ByteDone  => ByteDone,
        ReadData  => ReadData,
        Ack       => Ack,
        TxBit     => TxBit,
        BitStart  => BitStart,
        DriveEn   => DriveEn
    );

    PROCESS (SysClk, nRST)
    BEGIN
        IF nRST = '0' THEN
            StateC <= IDLE;
        ELSIF rising_edge(SysClk) THEN
            StateC <= StateN;
        END IF;
    END PROCESS;

    PROCESS (ALL)
    BEGIN
        StateN <= StateC;
        CASE(StateC) IS

            WHEN IDLE =>
            IF Run = '1' THEN
                Busy   <= '0';
                StateN <= START;
            END IF;

            WHEN START =>
            IF BitDone = '1' THEN
                Busy     <= '1';
                I2cStart <= '1';
                StateN   <= CTRL_BYTE;
            END IF;

            WHEN CTRL_BYTE =>
            Busy      <= '1';
            WriteData <= X"A0";
            IF ACK = '1' AND ByteDone = '1' THEN
                StateN <= ADDR_H;
            ELSIF Cmd = b"10" THEN
                StateN <= CTRL_BYTE_R;
            END IF;

            WHEN ADDR_H =>
            IF ACK = '1' AND ByteDone = '1' THEN
                Busy      <= '1';
                WriteData <= Addr(14 DOWNTO 8);
                StateN    <= ADDR_L;
            END IF;

            WHEN ADDR_L =>
            Busy      <= '1';
            WriteData <= Addr(7 DOWNTO 0);
            IF ACK = '1' AND Cmd = b"00" AND ByteDone = '1' THEN
                StateN <= DATA;
            ELSIF ACK = '1' AND Cmd = b"01" AND ByteDone = '1' THEN
                StateN <= REP_START;
            END IF;

            WHEN DATA =>
            IF ACK = '1' AND ByteDone = '1' THEN
                Busy      <= '1';
                WriteData <= Wdata;
                StateN    <= STOP;
            END IF;

            WHEN STOP =>
            IF BitDone = '1' THEN
                Busy    <= '0';
                Done    <= '1';
                I2cStop <= '1';
                StateN  <= IDLE;
            END IF;

            WHEN REP_START =>
            IF BitDone = '1' THEN
                Busy   <= '1';
                StateN <= CTRL_BYTE_R;
            END IF;

            WHEN CTRL_BYTE_R =>
            IF ACK = '1' AND ByteDone = '1' THEN
                Busy      <= '1';
                WriteData <= x"A1";
                StateN    <= READ_DATA;
            END IF;

            WHEN READ_DATA =>
            IF ACK = '1' AND ByteDone = '1' THEN
                Busy     <= '1';
                ReadData <= RDATA;
                StateN   <= STOP;
            END IF;

            WHEN OTHERS => StateN <= IDLE;

        END CASE;
    END PROCESS;

END Behavioral;