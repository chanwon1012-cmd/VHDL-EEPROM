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

ENTITY EepromCtrlTop IS
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
        SdaIn  : IN STD_LOGIC;
        SclOut : OUT STD_LOGIC;
        SdaOut : OUT STD_LOGIC;
        SdaOe  : OUT STD_LOGIC
    );
END EepromCtrlTop;

ARCHITECTURE Behavioral OF EepromCtrlTop IS

    TYPE State IS (IDLE, START, CTRL_BYTE, ADDR_H, ADDR_L, DATA, STOP, REP_START, CTRL_BYTE_R, READ_DATA);
    SIGNAL StateC, StateN : State;

    SIGNAL BitStart  : STD_LOGIC;
    SIGNAL Bitdone   : STD_LOGIC;
    SIGNAL I2cStart  : STD_LOGIC;
    SIGNAL I2cStop   : STD_LOGIC;
    SIGNAL ByteDone  : STD_LOGIC;
    SIGNAL ByteStart : STD_LOGIC;
    SIGNAL rw        : STD_LOGIC;
    SIGNAL ACK       : STD_LOGIC;
    SIGNAL TxBit     : STD_LOGIC;
    SIGNAL DriveEn   : STD_LOGIC;
    SIGNAL SdaLatch  : STD_LOGIC;
    SIGNAL WriteData : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL ReadData  : STD_LOGIC_VECTOR(7 DOWNTO 0);

 
    component I2cCtrlTop is
        port (
            clk   : in std_logic;
            reset : in std_logic;
            
        );
    end component;

BEGIN


    PROCESS (SysClk, nRST)
    BEGIN
        IF nRST = '0' THEN
            StateC <= IDLE;
        ELSIF rising_edge(SysClk) THEN
            StateC <= StateN;
        END IF;
    END PROCESS;

    PROCESS (StateC, Run, Cmd, Addr, Wdata, BitDone, ACK, ByteDone)
    BEGIN
        StateN    <= StateC;
        Busy      <= '0';
        Done      <= '0';
        I2cStart  <= '0';
        ByteStart <= '0';
        rw        <= '0';
        I2cStop   <= '0';
        WriteData <= (OTHERS => '0');

        CASE(StateC) IS

            WHEN IDLE =>
            IF Run = '1' THEN
                Busy   <= '0';
                StateN <= START;
            END IF;

            WHEN START =>
            Busy     <= '1';
            I2cStart <= '1';
            IF BitDone = '1' THEN
                ByteStart <= '1';
                rw        <= '0';
                StateN    <= CTRL_BYTE;
            END IF;

            WHEN CTRL_BYTE =>
            Busy <= '1';
            IF Cmd = b"10" THEN
                StateN <= CTRL_BYTE_R;
            ELSE
                ByteStart <= '1';
                WriteData <= X"A0";
                rw        <= '0';
                IF ACK = '1' AND ByteDone = '1' THEN
                    StateN <= ADDR_H;
                END IF;
            END IF;

            WHEN ADDR_H =>
            ByteStart <= '1';
            WriteData <= '0' & Addr(14 DOWNTO 8);
            rw        <= '0';
            IF ACK = '1' AND ByteDone = '1' THEN
                Busy   <= '1';
                StateN <= ADDR_L;
            END IF;

            WHEN ADDR_L =>
            Busy      <= '1';
            ByteStart <= '1';
            WriteData <= Addr(7 DOWNTO 0);
            IF ACK = '1' AND Cmd = b"00" AND ByteDone = '1' THEN
                StateN <= DATA;
            ELSIF ACK = '1' AND Cmd = b"01" AND ByteDone = '1' THEN
                I2cStart <= '1';
                StateN   <= REP_START;
            END IF;

            WHEN DATA =>
            ByteStart <= '1';
            WriteData <= Wdata;
            IF ACK = '1' AND ByteDone = '1' THEN
                Busy   <= '1';
                StateN <= STOP;
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
                rw        <= '0';
                ByteStart <= '1';
                Busy      <= '1';
                StateN    <= CTRL_BYTE_R;
            END IF;

            WHEN CTRL_BYTE_R =>
            rw        <= '0';
            ByteStart <= '1';
            WriteData <= X"A1";
            IF ACK = '1' AND ByteDone = '1' THEN
                Busy   <= '1';
                StateN <= READ_DATA;
            END IF;

            WHEN READ_DATA =>
            ByteStart <= '1';
            rw        <= '1';
            IF ACK = '1' AND ByteDone = '1' THEN
                Busy   <= '1';
                StateN <= STOP;
            END IF;

            WHEN OTHERS => StateN <= IDLE;

        END CASE;
    END PROCESS;

END Behavioral;