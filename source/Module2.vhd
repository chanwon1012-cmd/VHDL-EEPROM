LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

USE work.array_def.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY Module2 IS
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
END Module2;

ARCHITECTURE Behavioral OF Module2 IS
    -- 1/FF
    SIGNAL H_REG : std_logic_bit16 (DATA_DEPTH - 1 DOWNTO 0);
    SIGNAL L_REG : std_logic_bit16 (DATA_DEPTH - 1 DOWNTO 0);

    -- 2/FF
    SIGNAL H_SUM_TEMP2_D1 : STD_LOGIC_VECTOR(18 DOWNTO 0);
    SIGNAL L_SUM_TEMP2_D1 : STD_LOGIC_VECTOR(18 DOWNTO 0);

    SIGNAL En_D    : STD_LOGIC;
    SIGNAL En_D_D1 : STD_LOGIC;

    SIGNAL H_SUM_TEMP  : STD_LOGIC_VECTOR(18 DOWNTO 0);
    SIGNAL L_SUM_TEMP  : STD_LOGIC_VECTOR(18 DOWNTO 0);
    SIGNAL H_SUM_TEMP2 : STD_LOGIC_VECTOR(18 DOWNTO 0);
    SIGNAL L_SUM_TEMP2 : STD_LOGIC_VECTOR(18 DOWNTO 0);
BEGIN

    PROCESS (CLK, nRST)
    BEGIN
        IF nRST = '0' THEN
            En_D  <= '0';
            H_REG <= ((OTHERS => ((OTHERS => '0'))));
            L_REG <= ((OTHERS => ((OTHERS => '0'))));
        ELSIF rising_edge(CLK) THEN
            En_D <= En;

            IF En = '1' THEN
                H_REG <= H_data;
                L_REG <= L_data;
            END IF;
        END IF;
    END PROCESS;
    H_SUM_TEMP <= STD_LOGIC_VECTOR(
        RESIZE(UNSIGNED(H_REG(0)), 19) +
        RESIZE(UNSIGNED(H_REG(1)), 19) +
        RESIZE(UNSIGNED(H_REG(2)), 19) +
        RESIZE(UNSIGNED(H_REG(3)), 19) +
        RESIZE(UNSIGNED(H_REG(4)), 19) +
        RESIZE(UNSIGNED(H_REG(5)), 19) +
        RESIZE(UNSIGNED(H_REG(6)), 19) +
        RESIZE(UNSIGNED(H_REG(7)), 19)
        );

    L_SUM_TEMP <= STD_LOGIC_VECTOR(
        RESIZE(UNSIGNED(L_REG(0)), 19) +
        RESIZE(UNSIGNED(L_REG(1)), 19) +
        RESIZE(UNSIGNED(L_REG(2)), 19) +
        RESIZE(UNSIGNED(L_REG(3)), 19) +
        RESIZE(UNSIGNED(L_REG(4)), 19) +
        RESIZE(UNSIGNED(L_REG(5)), 19) +
        RESIZE(UNSIGNED(L_REG(6)), 19) +
        RESIZE(UNSIGNED(L_REG(7)), 19)
        );

    H_SUM_TEMP2 <= STD_LOGIC_VECTOR(
        RESIZE(UNSIGNED(H_SUM_TEMP), 19) +
        RESIZE(UNSIGNED(L_SUM_TEMP(18 DOWNTO 16)), 19)
        );

    L_SUM_TEMP2 <= "000" & L_SUM_TEMP(15 DOWNTO 0);

    PROCESS (CLk, nRST)
    BEGIN
        IF nRST = '0' THEN
            En_D_D1        <= '0';
            H_SUM_TEMP2_D1 <= (OTHERS => '0');
            L_SUM_TEMP2_D1 <= (OTHERS => '0');
        ELSIF rising_edge(CLK) THEN
            En_D_D1        <= En_D;
            H_SUM_TEMP2_D1 <= H_SUM_TEMP2;
            L_SUM_TEMP2_D1 <= L_SUM_TEMP2;
        END IF;
    END PROCESS;

    Done  <= En_D_D1;
    H_sum <= H_SUM_TEMP2_D1;
    L_sum <= L_SUM_TEMP2_D1;

END Behavioral;