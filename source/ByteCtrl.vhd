
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.array_def.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ByteCtrl is
    port
    (
        -- Input
        -- System
        SysClk    : in std_logic;
        nRST      : in std_logic;
        -- I2c
        ByteStart : in std_logic;
        rw        : in std_logic;
        WriteData : in std_logic_vector (7 downto 0);
        -- BitCtrl
        BitDone   : in std_logic;
        SdaLatch  : in std_logic;
        -- Output
        -- I2c
        ByteDone  : out std_logic;
        ReadData  : out std_logic_vector (7 downto 0);
        Ack       : out std_logic;
        -- BitCtrl
        TxBit     : out std_logic;
        BitStart  : out std_logic;
        DriveEn   : out std_logic
    );
end ByteCtrl;
architecture Behavioral of ByteCtrl is
    type State is (IDLE, LOAD, SHIFT_BIT, SHIFT_BIT_WAIT, ACK_CHECK, DONE);
    signal StateC, StateN : State;
    signal DataReg        : std_logic_vector (7 downto 0);
    signal Cnt            : integer range 0 to 8;
begin
    -- Counter
    process (SysClk, nRST)
    begin
        if nRST = '0' then
            Cnt <= 8;
        elsif Rising_edge(SysClk) then
            if StateC = LOAD then
                Cnt <= 8;
            elsif StateC = SHIFT_BIT and BitDone = '1' then
                Cnt <= Cnt - 1;
            end if;
        end if;
    end process;
    -- S Logic
    process (SysClk, nRST)
    begin
        if nRST = '0' then
            StateC <= IDLE;
        elsif rising_edge(SysClk) then
            StateC <= StateN;
        end if;
    end process;
    -- C Logic
    process (StateC, rw, WriteData, SdaLatch, DataReg, ByteStart, BitDone, Cnt)
    begin
        StateN   <= StateC;
        ByteDone <= '0';
        Ack      <= '0';
        TxBit    <= '0';
        BitStart <= '0';
        DriveEn  <= '0';
        ReadData <= (others => '0');
        case(StateC) is

            when IDLE =>
            if ByteStart = '1' then
                StateN      <= LOAD;
            else StateN <= IDLE;
            end if;
            when LOAD =>
            Bitstart <= '1';
            DriveEn  <= not rw;
            DataReg  <= WriteData;
            txBit    <= WriteData(7);
            StateN   <= SHIFT_BIT;
            when SHIFT_BIT =>
            if BitDone = '1' then
                DataReg     <= DataReg(6 downto 0) & SdaLatch;
                TxBit       <= DataReg(6);
                StateN      <= SHIFT_BIT_WAIT;
            else StateN <= SHIFT_BIT;
            end if;
            when SHIFT_BIT_WAIT =>
            BitStart <= '1';
            if Cnt = 0 then
                DriveEn     <= rw;
                StateN      <= ACK_CHECK;
            else StateN <= SHIFT_BIT;
            end if;
            when ACK_CHECK =>
            if BitDone = '1' then
                ACK         <= SdaLatch;
                StateN      <= DONE;
            else StateN <= ACK_CHECK;
            end if;
            when DONE =>
            ByteDone              <= '1';
            ReadData              <= DataReg;
            StateN                <= IDLE;
            when others => StateN <= IDLE;
        end case;
    end process;
end Behavioral;