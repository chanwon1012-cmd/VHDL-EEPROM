
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity I2cCtrlTop is
    port
    (
        I2cStart  : in std_logic;
        I2cStop   : in std_logic;
        ByteStart : in std_logic;
        rw        : in std_logic;
        WriteData : in std_logic_vector(7 downto 0);
        SdaIn     : in std_logic;

        BitDone   : out std_logic;
        ReadData  : out std_logic;
        ACK       : out std_logic;
        SclOut    : out std_logic;
        SdaOut    : out std_logic;
        SdaOe     : out std_logic
    );
end I2cCtrlTop;

architecture Behavioral of I2cCtrlTop is

    component BitCtrl is
        generic
        (
            T_LOW    : integer := 90;
            T_SETUP  : integer := 5;
            T_HIGH   : integer := 30;
            T_HD_STA : integer := 30;
            T_SU_STO : integer := 30
        );
        port
        (
            SysClk   : in std_logic;
            nRST     : in std_logic;

            BitStart : in std_logic;
            I2cStart : in std_logic;
            I2cStop  : in std_logic;
            DriveEn  : in std_logic;
            TxBit    : in std_logic;
            SdaIn    : in std_logic;

            SclOut   : out std_logic;
            SdaOe    : out std_logic;
            SdaOut   : out std_logic;
            BitDone  : out std_logic;
            SdaLatch : out std_logic
        );
    end component;

    component ByteCtrl is
        port
        (
            SysClk    : in std_logic;
            nRST      : in std_logic;
            -- I2c
            rw        : in std_logic;
            ByteStart : in std_logic;
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
    end component;

begin

    BitCtrl_Inst : BitCtrl
    port map
    (
        SysClk   => SysClk,
        nRST     => nRST,
        BitStart => BitStart,
        I2cStart => I2cStart,
        I2cStop  => I2cStop,
        DriveEn  => DriveEn,
        TxBit    => TxBit,
        SdaIn    => SdaIn,
        SdaOe    => SdaOe,
        SdaOut   => SdaOut,
        SclOut   => SclOut,
        BitDone  => Bitdone,
        SdaLatch => SdaLatch
    );

    ByteCtrl_Inst : ByteCtrl
    port
    map(
    SysClk    => SysClk,
    nRST      => nRST,
    ByteStart => ByteStart,
    rw        => rw,
    WriteData => WriteData,
    BitDone   => BitDone,
    SdaLatch  => SdaLatch,
    ByteDone  => ByteDone,
    ReadData  => Rdata,
    Ack       => Ack,
    TxBit     => TxBit,
    BitStart  => BitStart,
    DriveEn   => DriveEn
    );

end Behavioral;
