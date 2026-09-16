
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

ENTITY ByteCtrlTb IS
    --  Port ( );
END ByteCtrlTb;

ARCHITECTURE Behavioral OF ByteCtrlTb IS
    CONSTANT CLK_PERIOD : TIME := 20 ns;

    SIGNAL SysClk    : STD_LOGIC := '0';
    SIGNAL nRST      : STD_LOGIC;
    SIGNAL ByteStart : STD_LOGIC;
    SIGNAL rw        : STD_LOGIC;
    SIGNAL WriteData : STD_LOGIC_VECTOR (7 DOWNTO 0);
    SIGNAL BitDone   : STD_LOGIC;
    SIGNAL SdaLatch  : STD_LOGIC;

    SIGNAL ByteDone : STD_LOGIC;
    SIGNAL ReadData : STD_LOGIC_VECTOR (7 DOWNTO 0);
    SIGNAL Ack      : STD_LOGIC;
    SIGNAL TxBit    : STD_LOGIC;
    SIGNAL BitStart : STD_LOGIC;
    SIGNAL DriveEn  : STD_LOGIC;

BEGIN

    DUT : ENTITY work.ByteCtrl
        PORT MAP(
            SysClk    => SysClk,
            nRST      => nRST,
            ByteStart => ByteStart,
            rw        => rw,
            WriteData => WriteData,
            BitDone   => BitDone,
            SdaLatch  => SdaLatch,

            ByteDone => ByteDone,
            ReadData => ReadData,
            Ack      => Ack,
            TxBit    => TxBit,
            BitStart => BitStart,
            DriveEn  => DriveEn
        );

    SysClk <= NOT SysClk AFTER CLK_PERIOD / 2;

    simulation : PROCESS
    BEGIN
        nRST <= '0';
        WAIT FOR CLK_PERIOD * 5;
        nRST <= '1';
        WAIT UNTIL rising_edge(SysClk);

        -- Write Data
        rw        <= '0';
        WriteData <= x"A0";
        ByteStart <= '1';
        WAIT UNTIL rising_edge(SysClk);
        ByteStart <= '0';

        -- 1bit Shift Tx

        -- ByteDataShift : FOR i IN 0 TO 8 LOOP
        --     WAIT UNTIL rising_edge(SysClk) AND BitStart = '1';
        --     WAIT FOR CLK_PERIOD * 5 + CLK_PERIOD / 4;
        --     IF i = 8 THEN
        --         SdaLatch <= '1';
        --     ELSE
        --         SdaLatch <= '0';
        --     END IF;
        --     BitDone <= '1';
        --     WAIT UNTIL rising_edge(SysClk);
        --     BitDone <= '0';
        -- END LOOP; -- Byte Shift
        -- WAIT;

        ByteDataShift : FOR i IN 0 TO 8 LOOP
            LOOP
                WAIT UNTIL rising_edge(SysClk);
                EXIT WHEN BitStart = '1';
            END LOOP;

            WAIT FOR CLK_PERIOD * 5 + CLK_PERIOD / 4;
            IF i = 8 THEN
                SdaLatch <= '1';
            ELSE
                SdaLatch <= '0';
            END IF;
            BitDone <= '1';
            WAIT UNTIL rising_edge(SysClk);
            BitDone <= '0';
        END LOOP; -- ByteDataShift
        WAIT;

    END PROCESS;

END Behavioral;