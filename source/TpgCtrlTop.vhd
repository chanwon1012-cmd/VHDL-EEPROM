
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

USE work.array_def.ALL;

ENTITY TpgCtrlTop IS
    PORT (
        SysClk : IN STD_LOGIC;
        nRST   : IN STD_LOGIC;

        -- AP INTERFACE
        IfClk  : IN STD_LOGIC;
        IfAle  : IN STD_LOGIC;
        IfRd   : IN STD_LOGIC;
        IfWr   : IN STD_LOGIC;
        IfData : INOUT STD_LOGIC_VECTOR(23 DOWNTO 0)

        -- EEPROM (??? ?? ??)
    );
END TpgCtrlTop;

ARCHITECTURE Behavioral OF TpgCtrlTop IS

    COMPONENT Module1 IS
        GENERIC (
            DATA_DEPTH : POSITIVE := 8
        );
        PORT (
            CLK  : IN STD_LOGIC;
            nRST : IN STD_LOGIC;
            En   : IN STD_LOGIC;

            H_data : IN std_logic_bit16 (DATA_DEPTH - 1 DOWNTO 0);
            L_data : IN std_logic_bit16 (DATA_DEPTH - 1 DOWNTO 0);

            H_sum : OUT STD_LOGIC_VECTOR(18 DOWNTO 0);
            L_sum : OUT STD_LOGIC_VECTOR(18 DOWNTO 0);

            Done : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT Module2 IS
        GENERIC (
            DATA_DEPTH : POSITIVE := 8
        );
        PORT (
            CLK  : IN STD_LOGIC;
            nRST : IN STD_LOGIC;
            En   : IN STD_LOGIC;

            H_data : IN std_logic_bit16 (DATA_DEPTH - 1 DOWNTO 0);
            L_data : IN std_logic_bit16 (DATA_DEPTH - 1 DOWNTO 0);

            H_sum : OUT STD_LOGIC_VECTOR(18 DOWNTO 0);
            L_sum : OUT STD_LOGIC_VECTOR(18 DOWNTO 0);

            Done : OUT STD_LOGIC
        );
    END COMPONENT;

    --addr[23:12] == 0x00f
    CONSTANT ADDR_HI : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"00F";

    --addr[11:0]
    CONSTANT Fun1_trig     : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"001";
    CONSTANT Fun1_H_Result : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"002";
    CONSTANT Fun1_L_Result : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"003";
    CONSTANT Fun2_trig     : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"004";
    CONSTANT Fun2_H_Result : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"005";
    CONSTANT Fun2_L_Result : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"006";

    CONSTANT DATA_H_0 : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"010";
    CONSTANT DATA_L_0 : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"011";
    CONSTANT DATA_H_1 : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"012";
    CONSTANT DATA_L_1 : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"013";
    CONSTANT DATA_H_2 : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"014";
    CONSTANT DATA_L_2 : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"015";
    CONSTANT DATA_H_3 : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"016";
    CONSTANT DATA_L_3 : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"017";
    CONSTANT DATA_H_4 : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"018";
    CONSTANT DATA_L_4 : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"019";
    CONSTANT DATA_H_5 : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"01A";
    CONSTANT DATA_L_5 : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"01B";
    CONSTANT DATA_H_6 : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"01C";
    CONSTANT DATA_L_6 : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"01D";
    CONSTANT DATA_H_7 : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"01E";
    CONSTANT DATA_L_7 : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"01F";

    SIGNAL Addr_H : STD_LOGIC;
    SIGNAL Addr_l : STD_LOGIC_VECTOR(11 DOWNTO 0);

    SIGNAL Fun1_en        : STD_LOGIC;
    SIGNAL Fun1_cond      : STD_LOGIC;
    SIGNAL Fun1_cond_prev : STD_LOGIC;
    SIGNAL Fun2_en        : STD_LOGIC;
    SIGNAL Fun2_cond      : STD_LOGIC;
    SIGNAL Fun2_cond_prev : STD_LOGIC;

    SIGNAL DATA_H     : std_logic_bit16 (7 DOWNTO 0);
    SIGNAL DATA_L     : std_logic_bit16 (7 DOWNTO 0);
    SIGNAL Addr_Latch : STD_LOGIC_VECTOR (23 DOWNTO 0);

    SIGNAL Fun1_H_sum, Fun1_L_sum : STD_LOGIC_VECTOR(18 DOWNTO 0);
    SIGNAL Fun2_H_sum, Fun2_L_sum : STD_LOGIC_VECTOR(18 DOWNTO 0);
    SIGNAL Fun1_Done, Fun2_Done   : STD_LOGIC;

BEGIN
    --Addr Flag
    Addr_h <= '1' WHEN Addr(23 DOWNTO 12) = ADDR_HI ELSE
        '0';
    Addr_l <= Addr(11 DOWNTO 0);

    --Function Enable Flag
    Fun1_cond <= '1' WHEN (Addr_h = '1' AND Addr_l = Fun1_trig AND WE = '1') ELSE
        '0';
    Fun2_cond <= '1' WHEN (Addr_h = '1' AND Addr_l = Fun2_trig AND WE = '1') ELSE
        '0';

    -- addr latch
    PROCESS (IfClk, nRST)
    BEGIN
        IF nRst = '0' THEN
            Addr_Latch <= (OTHERS => '0');
        ELSIF rising_clk(IfClk) THEN
            IF IfAle = '1' THEN
                Addr_Latch <= IfData;
            END IF;
        END IF;
    END PROCESS;

    -- WRITE
    PROCESS (IfClk, nRST)
    BEGIN
        IF nRST = '0' THEN
            Fun1_cond_prev <= '0';
            Fun1_en        <= '0';

            Fun2_cond_prev <= '0';
            Fun2_en        <= '0';

        ELSIF rising_clk(IfClk) THEN
            Fun1_cond_prev <= Fun1_cond;
            Fun1_en        <= Fun1_cond AND NOT Fun1_cond_prev;

            Fun2_cond_prev <= Fun2_cond;
            Fun2_en        <= Fun2_cond AND NOT Fun2_cond_prev;
        END IF;
    END PROCESS;

    PROCESS (IfClk, nRST)
    BEGIN
        IF nRST = '0' THEN
            DATA_H <= (OTHERS => (OTHERS => '0'));
            DATA_L <= (OTHERS => (OTHERS => '0'));

        ELSIF rising_edge(IfClk) THEN
            IF Addr_h = '1' AND We = '1' THEN
                CASE(Addr_l) IS
                    WHEN DATA_H_0 => DATA_H(0) <= Data_In;
                    WHEN DATA_L_0 => DATA_L(0) <= Data_In;
                    WHEN DATA_H_1 => DATA_H(1) <= Data_In;
                    WHEN DATA_L_1 => DATA_L(1) <= Data_In;
                    WHEN DATA_H_2 => DATA_H(2) <= Data_In;
                    WHEN DATA_L_2 => DATA_L(2) <= Data_In;
                    WHEN DATA_H_3 => DATA_H(3) <= Data_In;
                    WHEN DATA_L_3 => DATA_L(3) <= Data_In;
                    WHEN DATA_H_4 => DATA_H(4) <= Data_In;
                    WHEN DATA_L_4 => DATA_L(4) <= Data_In;
                    WHEN DATA_H_5 => DATA_H(5) <= Data_In;
                    WHEN DATA_L_5 => DATA_L(5) <= Data_In;
                    WHEN DATA_H_6 => DATA_H(6) <= Data_In;
                    WHEN DATA_L_6 => DATA_L(6) <= Data_In;
                    WHEN DATA_H_7 => DATA_H(7) <= Data_In;
                    WHEN DATA_L_7 => DATA_L(7) <= Data_In;
                    WHEN OTHERS   => NULL;
                END CASE;
            END IF;
        END IF;
    END PROCESS;
    -- READ
    PROCESS (Addr_h, Addr_l, Re, Fun1_H_sum, Fun1_L_sum, Fun2_H_sum, Fun2_L_sum)
    BEGIN

        Data_OUT <= (OTHERS => 'Z');

        IF Addr_h = '1' AND RE = '1' THEN
            CASE(Addr_L) IS
                WHEN Fun1_H_Result => Data_OUT <= Fun1_H_sum;
                WHEN Fun1_L_Result => Data_OUT <= Fun1_L_sum;
                WHEN Fun2_H_Result => Data_OUT <= Fun2_H_sum;
                WHEN Fun2_L_Result => Data_OUT <= Fun2_L_sum;
                WHEN OTHERS        => NULL;
            END CASE;
        END IF;
    END PROCESS;

    Module1 : Module1
    PORT MAP(
        CLK    => CLK,
        nRST   => nRST,
        En     => Fun1_en,
        H_data => DATA_H,
        L_data => DATA_L,
        H_sum  => Fun1_H_sum,
        L_sum  => Fun1_L_sum,
        Done   => Fun1_Done
    );

    Module2 : Module2
    PORT MAP(
        CLK    => CLK,
        nRST   => nRST,
        En     => Fun1_en,
        H_data => DATA_H,
        L_data => DATA_L,
        H_sum  => Fun1_H_sum,
        L_sum  => Fun1_L_sum,
        Done   => Fun1_Done
    );

END Behavioral;