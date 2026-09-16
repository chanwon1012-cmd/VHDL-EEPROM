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

ENTITY I2cMasterTb IS
    --  Port ( );
END I2cMasterTb;

ARCHITECTURE Behavioral OF I2cMasterTb IS

    CONSTANT CLK_PERIOD : TIME := 20 ns;

    SIGNAL SysClk   : STD_LOGIC := '0';
    SIGNAL nRST     : STD_LOGIC;
    SIGNAL Cmd      : STD_LOGIC_VECTOR (1 DOWNTO 0);
    SIGNAL Addr     : STD_LOGIC_VECTOR (14 DOWNTO 0);
    SIGNAL Run      : STD_LOGIC;
    SIGNAL Wdata    : STD_LOGIC_VECTOR (7 DOWNTO 0);
    SIGNAL Busy     : STD_LOGIC;
    SIGNAL Done     : STD_LOGIC;
    SIGNAL Rdata    : STD_LOGIC_VECTOR (7 DOWNTO 0);
    SIGNAL Nack_err : STD_LOGIC;
    SIGNAL SdaIn    : STD_LOGIC;
    SIGNAL SclOut   : STD_LOGIC;
    SIGNAL SdaOut   : STD_LOGIC;
    SIGNAL SdaOe    : STD_LOGIC;

BEGIN
    DUT : ENTITY work.I2cMaster
        PORT MAP(
            SysClk   => SysClk,
            nRST     => nRST,
            Cmd      => Cmd,
            Addr     => Addr,
            Run      => Run,
            Wdata    => Wdata,
            Busy     => Busy,
            Done     => Done,
            Rdata    => Rdata,
            Nack_err => Nack_err,
            SdaIn    => SdaIn,
            SdaOut   => SdaOut,
            SdaOe    => SdaOe,
            SclOut   => SclOut
        );

    SysClk <= NOT SysClk AFTER CLK_PERIOD / 2;

    -- EEPROM 
    SdaIn <= '0' WHEN SdaOe = '0' ELSE '1';

    simulation : PROCESS
    BEGIN

        nRST <= '0';
        WAIT FOR CLK_PERIOD * 5;
        nRST <= '1';
        WAIT UNTIL rising_edge(SysClk);

        -- Write: Addr=0x0055, Wdata=0xA5
        Cmd   <= b"00";
        Addr  <= "000000001010101";
        Wdata <= x"A5";
        Run   <= '1';
        WAIT UNTIL rising_edge(SysClk);
        Run   <= '0';

        WAIT UNTIL Done = '1';
        WAIT UNTIL rising_edge(SysClk);

        WAIT;
    END PROCESS;
END Behavioral;
