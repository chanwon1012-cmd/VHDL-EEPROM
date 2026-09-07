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

        -- EEPROM
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
    CONSTANT M1_trig     : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"001";
    CONSTANT M1_H_Result : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"002";
    CONSTANT M1_L_Result : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"003";
    CONSTANT M2_trig     : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"004";
    CONSTANT M2_H_Result : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"005";
    CONSTANT M2_L_Result : STD_LOGIC_VECTOR(11 DOWNTO 0) := X"006";

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

    SIGNAL M1_en        : STD_LOGIC;
    SIGNAL M1_en_d1     : STD_LOGIC;
    SIGNAL M1_en_sync   : STD_LOGIC;
    SIGNAL M1_cond      : STD_LOGIC;
    SIGNAL M1_cond_prev : STD_LOGIC;
    SIGNAL M2_en        : STD_LOGIC;
    SIGNAL M2_en_d1     : STD_LOGIC;
    SIGNAL M2_en_sync   : STD_LOGIC;
    SIGNAL M2_cond      : STD_LOGIC;
    SIGNAL M2_cond_prev : STD_LOGIC;

    SIGNAL DATA_H     : std_logic_bit16 (7 DOWNTO 0);
    SIGNAL DATA_L     : std_logic_bit16 (7 DOWNTO 0);
    SIGNAL Addr_Latch : STD_LOGIC_VECTOR (23 DOWNTO 0);

    SIGNAL M1_H_sum, M1_L_sum : STD_LOGIC_VECTOR(18 DOWNTO 0);
    SIGNAL M2_H_sum, M2_L_sum : STD_LOGIC_VECTOR(18 DOWNTO 0);
    SIGNAL M1_Done, M2_Done   : STD_LOGIC;

BEGIN
    --Addr Flag
    Addr_h <= '1' WHEN Addr_Latch(23 DOWNTO 12) = ADDR_HI ELSE
        '0';
    Addr_l <= Addr_Latch(11 DOWNTO 0);

    --Function Enable Flag
    M1_cond <= '1' WHEN (Addr_h = '1' AND Addr_l = M1_trig AND IfWr = '1') ELSE
        '0';
    M2_cond <= '1' WHEN (Addr_h = '1' AND Addr_l = M2_trig AND IfWr = '1') ELSE
        '0';

    -- addr latch
    PROCESS (IfClk, nRST)
    BEGIN
        IF nRst = '0' THEN
            Addr_Latch <= (OTHERS => '0');
        ELSIF rising_edge(IfClk) THEN
            IF IfAle = '1' THEN
                Addr_Latch <= IfData;
            END IF;
        END IF;
    END PROCESS;

    -- WRITE
    PROCESS (IfClk, nRST)
    BEGIN
        IF nRST = '0' THEN
            M1_cond_prev <= '0';
            M1_en        <= '0';
            M2_cond_prev <= '0';
            M2_en        <= '0';

        ELSIF rising_edge(IfClk) THEN
            M1_cond_prev <= M1_cond;
            M1_en        <= M1_cond AND NOT M1_cond_prev;
            M2_cond_prev <= M2_cond;
            M2_en        <= M2_cond AND NOT M2_cond_prev;
        END IF;
    END PROCESS;

    PROCESS (SysClk, nRST)
    BEGIN
        IF nRST = '0' THEN
            M1_en_d1   <= '0';
            M2_en_d1   <= '0';
            M1_en_sync <= '0';
            M2_en_sync <= '0';

        ELSIF rising_edge(SysClK) THEN
            M1_en_d1   <= M1_en;
            M1_en_sync <= M1_en_d1;

            M2_en_d1   <= M2_en;
            M2_en_sync <= M2_en_d1;
        END IF;
    END PROCESS;

    PROCESS (IfClk, nRST)
    BEGIN
        IF nRST = '0' THEN
            DATA_H <= (OTHERS => (OTHERS => '0'));
            DATA_L <= (OTHERS => (OTHERS => '0'));

        ELSIF rising_edge(IfClk) THEN
            IF Addr_h = '1' AND IfWr = '1' THEN
                CASE(Addr_l) IS
                    WHEN DATA_H_0 => DATA_H(0) <= IfData;
                    WHEN DATA_L_0 => DATA_L(0) <= IfData;
                    WHEN DATA_H_1 => DATA_H(1) <= IfData;
                    WHEN DATA_L_1 => DATA_L(1) <= IfData;
                    WHEN DATA_H_2 => DATA_H(2) <= IfData;
                    WHEN DATA_L_2 => DATA_L(2) <= IfData;
                    WHEN DATA_H_3 => DATA_H(3) <= IfData;
                    WHEN DATA_L_3 => DATA_L(3) <= IfData;
                    WHEN DATA_H_4 => DATA_H(4) <= IfData;
                    WHEN DATA_L_4 => DATA_L(4) <= IfData;
                    WHEN DATA_H_5 => DATA_H(5) <= IfData;
                    WHEN DATA_L_5 => DATA_L(5) <= IfData;
                    WHEN DATA_H_6 => DATA_H(6) <= IfData;
                    WHEN DATA_L_6 => DATA_L(6) <= IfData;
                    WHEN DATA_H_7 => DATA_H(7) <= IfData;
                    WHEN DATA_L_7 => DATA_L(7) <= IfData;
                    WHEN OTHERS   => NULL;
                END CASE;
            END IF;
        END IF;
    END PROCESS;

    -- READ
    PROCESS (Addr_h, Addr_l, IfRd, M1_H_sum, M1_L_sum, M2_H_sum, M2_L_sum)
    BEGIN
        IfData <= (OTHERS => 'Z');

        IF Addr_h = '1' AND IfRd = '1' THEN
            CASE(Addr_L) IS
                WHEN M1_H_Result => IfData <= "00000" & M1_H_sum;
                WHEN M1_L_Result => IfData <= "00000" & M1_L_sum;
                WHEN M2_H_Result => IfData <= "00000" & M2_H_sum;
                WHEN M2_L_Result => IfData <= "00000" & M2_L_sum;
                WHEN OTHERS => IfData      <= (OTHERS => 'Z');
            END CASE;
        END IF;
    END PROCESS;

    Module1_inst : Module1
    PORT MAP(
        CLK    => SysClK,
        nRST   => nRST,
        En     => M1_en_sync,
        H_data => DATA_H,
        L_data => DATA_L,
        H_sum  => M1_H_sum,
        L_sum  => M1_L_sum,
        Done   => M1_Done
    );

    Module2_inst : Module2
    PORT MAP(
        CLK    => SysClK,
        nRST   => nRST,
        En     => M2_en_sync,
        H_data => DATA_H,
        L_data => DATA_L,
        H_sum  => M2_H_sum,
        L_sum  => M2_L_sum,
        Done   => M2_Done
    );
END Behavioral;