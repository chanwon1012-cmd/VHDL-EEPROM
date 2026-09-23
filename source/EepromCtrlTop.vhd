library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.array_def.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity EepromCtrlTop is
    port
    (
        -- System
        SysClk   : in std_logic;
        nRST     : in std_logic;

        -- TpgCtrlTop
        Cmd      : in std_logic_vector (1 downto 0);
        Addr     : in std_logic_vector (14 downto 0);
        Run      : in std_logic;
        Wdata    : in std_logic_vector (7 downto 0);
        Busy     : out std_logic;
        Done     : out std_logic;
        Rdata    : out std_logic_vector (7 downto 0);
        Nack_err : out std_logic;

        -- Eeprom
        SdaIn    : in std_logic;
        SclOut   : out std_logic;
        SdaOut   : out std_logic;
        SdaOe    : out std_logic
    );
end EepromCtrlTop;

architecture Behavioral of EepromCtrlTop is

    type State is (IDLE, START, CTRL_BYTE, ADDR_H, ADDR_L, DATA, STOP, REP_START, CTRL_BYTE_R, READ_DATA);
    signal StateC, StateN : State;

    signal BitStart       : std_logic;
    signal Bitdone        : std_logic;
    signal I2cStart       : std_logic;
    signal I2cStop        : std_logic;
    signal ByteDone       : std_logic;
    signal ByteStart      : std_logic;
    signal rw             : std_logic;
    signal ACK            : std_logic;
    signal TxBit          : std_logic;
    signal DriveEn        : std_logic;
    signal SdaLatch       : std_logic;
    signal WriteData      : std_logic_vector(7 downto 0);

    component I2cCtrlTop is
        port
        (
            SysClk    : in std_logic;
            nRST      : in std_logic;
            I2cStart  : in std_logic;
            I2cStop   : in std_logic;
            ByteStart : in std_logic;
            rw        : in std_logic;
            WriteData : in std_logic_vector(7 downto 0);
            SdaIn     : in std_logic;
            BitDone   : out std_logic;
            ByteDone  : out std_logic;
            ReadData  : out std_logic_vector (7 downto 0);
            ACK       : out std_logic;
            SclOut    : out std_logic;
            SdaOut    : out std_logic;
            SdaOe     : out std_logic
        );
    end component;

begin

    I2cCtrlTopInst : I2cCtrlTop
    port map
    (
        SysClk    => SysClk,
        nRST      => nRST,
        I2cStart  => I2cStart,
        I2cStop   => I2cStop,
        ByteStart => ByteStart,
        rw        => rw,
        WriteData => WriteData,
        SdaIn     => SdaIn,
        BitDone   => BitDone,
        ByteDone  => ByteDone,
        ReadData  => Rdata,
        ACK       => ACK,
        SclOut    => SclOut,
        SdaOut    => SdaOut,
        SdaOe     => SdaOe
    );

    process (SysClk, nRST)
    begin
        if nRST = '0' then
            StateC <= IDLE;
        elsif rising_edge(SysClk) then
            StateC <= StateN;
        end if;
    end process;

    process (StateC, Run, Cmd, Addr, Wdata, BitDone, ACK, ByteDone)
    begin
        StateN    <= StateC;
        Busy      <= '0';
        Done      <= '0';
        I2cStart  <= '0';
        ByteStart <= '0';
        rw        <= '0';
        I2cStop   <= '0';
        WriteData <= (others => '0');

        case(StateC) is

            when IDLE =>
            if Run = '1' then
                Busy   <= '0';
                StateN <= START;
            end if;

            when START =>
            Busy     <= '1';
            I2cStart <= '1';
            if BitDone = '1' then
                ByteStart <= '1';
                rw        <= '0';
                StateN    <= CTRL_BYTE;
            end if;

            when CTRL_BYTE =>
            Busy <= '1';
            if Cmd = b"10" then
                StateN         <= CTRL_BYTE_R;
            else ByteStart <= '1';
                WriteData      <= X"A0";
                rw             <= '0';
                if ACK = '1' and ByteDone = '1' then
                    StateN <= ADDR_H;
                end if;
            end if;

            when ADDR_H =>
            ByteStart <= '1';
            WriteData <= '0' & Addr(14 downto 8);
            rw        <= '0';
            if ACK = '1' and ByteDone = '1' then
                Busy   <= '1';
                StateN <= ADDR_L;
            end if;

            when ADDR_L =>
            Busy      <= '1';
            ByteStart <= '1';
            WriteData <= Addr(7 downto 0);
            if ACK = '1' and Cmd = b"00" and ByteDone = '1' then
                StateN <= DATA;
            elsif ACK = '1' and Cmd = b"01" and ByteDone = '1' then
                I2cStart <= '1';
                StateN   <= REP_START;
            end if;

            when DATA =>
            ByteStart <= '1';
            WriteData <= Wdata;
            if ACK = '1' and ByteDone = '1' then
                Busy   <= '1';
                StateN <= STOP;
            end if;

            when STOP =>
            if BitDone = '1' then
                Busy    <= '0';
                Done    <= '1';
                I2cStop <= '1';
                StateN  <= IDLE;
            end if;

            when REP_START =>
            if BitDone = '1' then
                rw        <= '0';
                ByteStart <= '1';
                Busy      <= '1';
                StateN    <= CTRL_BYTE_R;
            end if;

            when CTRL_BYTE_R =>
            rw        <= '0';
            ByteStart <= '1';
            WriteData <= X"A1";
            if ACK = '1' and ByteDone = '1' then
                Busy   <= '1';
                StateN <= READ_DATA;
            end if;

            when READ_DATA =>
            ByteStart <= '1';
            rw        <= '1';
            if ACK = '1' and ByteDone = '1' then
                Busy   <= '1';
                StateN <= STOP;
            end if;

            when others => StateN <= IDLE;

        end case;
    end process;

end Behavioral;
