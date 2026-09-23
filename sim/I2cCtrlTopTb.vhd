library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

use work.array_def.all;
-- arithmetic functions with Signed or Unsigned values
-- Uncomment the following library declaration if using

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity I2cCtrlTopTb is
    --  Port ( );
end I2cCtrlTopTb;

architecture Behavioral of I2cCtrlTopTb is

    constant CLK_PERIOD : time := 20 ns;
    -- BitCtrl 1비트 타이밍: (T_LOW+1)+(T_SETUP+1)+(T_HIGH+1) = 91+6+31 = 128 클럭
    constant BIT_PERIOD : time := 128 * CLK_PERIOD;

    signal SysClk    : std_logic := '0';
    signal nRST      : std_logic;
    signal I2cStart  : std_logic := '0';
    signal I2cStop   : std_logic := '0';
    signal ByteStart : std_logic := '0';
    signal rw        : std_logic := '0';
    signal WriteData : std_logic_vector(7 downto 0) := (others => '0');
    signal SdaIn     : std_logic := '1';
    signal BitDone   : std_logic;
    signal ByteDone  : std_logic;
    signal ReadData  : std_logic_vector (7 downto 0);
    signal ACK       : std_logic;
    signal SclOut    : std_logic;
    signal SdaOut    : std_logic;
    signal SdaOe     : std_logic;

begin

    DUT : entity work.I2cCtrlTop
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
            ReadData  => ReadData,
            ACK       => ACK,
            SclOut    => SclOut,
            SdaOut    => SdaOut,
            SdaOe     => SdaOe
        );

    SysClk <= not SysClk after CLK_PERIOD / 2;

    simulation : process
    begin
        nRST <= '0';
        wait for CLK_PERIOD * 5;
        nRST <= '1';
        wait until rising_edge(SysClk);

        -- 1 I2cStart ?? ?? -> GEN_START 
        I2cStart <= '1';
        wait until rising_edge(SysClk);
        I2cStart <= '0';
        wait until BitDone = '1';
        wait until rising_edge(SysClk);

        -- 2 Write ?? ? ACK '0'
        rw        <= '0';
        WriteData <= x"A5";
        ByteStart <= '1';
        wait until rising_edge(SysClk);
        ByteStart <= '0';

        wait for BIT_PERIOD * 8;   -- 
        SdaIn <= '0';              -- ACK
        wait until ByteDone = '1';
        wait until rising_edge(SysClk);

        -- 3
        rw        <= '0';
        WriteData <= x"5A";
        ByteStart <= '1';
        wait until rising_edge(SysClk);
        ByteStart <= '0';

        wait for BIT_PERIOD * 8;
        SdaIn <= '1';              -- NACK
        wait until ByteDone = '1';
        wait until rising_edge(SysClk);
        SdaIn <= '1';              -- 

        -- 4
        rw        <= '1';
        ByteStart <= '1';
        wait until rising_edge(SysClk);
        ByteStart <= '0';

        SdaIn <= '1';              -- bit7
        wait for BIT_PERIOD;
        SdaIn <= '1';              -- bit6
        wait for BIT_PERIOD;
        SdaIn <= '0';              -- bit5
        wait for BIT_PERIOD;
        SdaIn <= '0';              -- bit4
        wait for BIT_PERIOD;
        SdaIn <= '0';              -- bit3
        wait for BIT_PERIOD;
        SdaIn <= '0';              -- bit2
        wait for BIT_PERIOD;
        SdaIn <= '1';              -- bit1
        wait for BIT_PERIOD;
        SdaIn <= '1';              -- bit0
        wait until ByteDone = '1';
        wait until rising_edge(SysClk);

        -- 5. STOP 
        I2cStop <= '1';
        wait until rising_edge(SysClk);
        I2cStop <= '0';
        wait until BitDone = '1';
        wait until rising_edge(SysClk);

        wait;
    end process;

end Behavioral;
