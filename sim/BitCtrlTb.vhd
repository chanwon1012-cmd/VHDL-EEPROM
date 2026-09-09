----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2026/09/09 17:33:44
-- Design Name: 
-- Module Name: BitCtrlTb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY BitCtrlTb IS
    --  Port ( );
END BitCtrlTb;

ARCHITECTURE Behavioral OF BitCtrlTb IS
    -- Input
    SIGNAL SysClk   : STD_LOGIC := '0';
    SIGNAL nRST     : STD_LOGIC := '0';
    SIGNAL BitStart : STD_LOGIC := '0';
    SIGNAL I2cStart : STD_LOGIC := '0';
    SIGNAL I2cStop  : STD_LOGIC := '0';
    SIGNAL DriveEn  : STD_LOGIC := '0';
    SIGNAL TxBit    : STD_LOGIC := '0';
    SIGNAL SdaIn    : STD_LOGIC := '1';
    -- Output
    SIGNAL SclOut   : STD_LOGIC;
    SIGNAL SdaOe    : STD_LOGIC;
    SIGNAL SdaOut   : STD_LOGIC;
    SIGNAL BitDone  : STD_LOGIC;
    SIGNAL SdaLatch : STD_LOGIC;

    CONSTANT CLK_PERIOD : TIME := 20 ns;

BEGIN

    DUT : ENTITY work.BitCtrl
        PORT MAP(
            SysClk   => SysClk,
            nRST     => nRST,
            BitStart => BitStart,
            I2cStart => I2cStart,
            I2cStop  => I2cStop,
            DriveEn  => DriveEn,
            TxBit    => TxBit,
            SdaIn    => SdaIn,

            SclOut   => SclOut,
            SdaOe    => SdaOe,
            SdaOut   => SdaOut,
            BitDone  => BitDone,
            SdaLatch => SdaLatch
        );

    -- Clk 
    SysClk <= NOT SysClk AFTER CLK_PERIOD / 2;

    -- Simulation
    Simulation : PROCESS
    BEGIN
        nRST <= '0';
        WAIT FOR CLK_PERIOD * 5;
        nRST <= '1';
        WAIT UNTIL rising_edge(SysClk);

        -- Test 1
        DriveEn  <= '1';
        TxBit    <= '1';
        BitStart <= '1';
        WAIT UNTIL rising_edge(SysClk);
        BitStart <= '0';

        WAIT UNTIL BitDone = '1';
        WAIT UNTIL rising_edge(SysClk);
    END PROCESS;
END Behavioral;