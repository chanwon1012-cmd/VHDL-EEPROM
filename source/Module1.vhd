
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

ENTITY Module1 IS
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
END Module1;

ARCHITECTURE Behavioral OF Module1 IS

    SIGNAL H_REG : std_logic_bit16 (DATA_DEPTH - 1 DOWNTO 0);
    SIGNAL L_REG : std_logic_bit16 (DATA_DEPTH - 1 DOWNTO 0);

    SIGNAL H_TEMP_REG : std_logic_bit18 (1 DOWNTO 0);
    SIGNAL L_TEMP_REG : std_logic_bit18 (1 DOWNTO 0);

    SIGNAL H_SUM_REG : STD_LOGIC_VECTOR(18 DOWNTO 0);
    SIGNAL L_SUM_REG : STD_LOGIC_VECTOR(18 DOWNTO 0);

    SIGNAL EN_D1 : STD_LOGIC;
    SIGNAL EN_D2 : STD_LOGIC;

BEGIN

    PROCESS (CLK, nRST) --FF
    BEGIN
        IF nRST = '0' THEN
            H_REG <= (OTHERS => (OTHERS => '0'));
            L_REG <= (OTHERS => (OTHERS => '0'));

            H_TEMP_REG <= (OTHERS => (OTHERS => '0'));
            L_TEMP_REG <= (OTHERS => (OTHERS => '0'));

            H_SUM_REG <= (OTHERS => '0');
            L_SUM_REG <= (OTHERS => '0');

            EN_D1 <= '0';
            EN_D2 <= '0';
            Done  <= '0';

        ELSIF rising_edge(CLK) THEN

            EN_D1 <= En;
            EN_D2 <= EN_D1;
            Done  <= EN_D2;

            IF En = '1' THEN
                -- 1clk
                H_REG <= H_data;
                L_REG <= L_data;
            END IF;

            IF EN_D1 = '1' THEN

                -- 2clk
                H_TEMP_REG(0) <= STD_LOGIC_VECTOR(
                RESIZE(UNSIGNED(H_REG(0)), 18) +
                RESIZE(UNSIGNED(H_REG(1)), 18) +
                RESIZE(UNSIGNED(H_REG(2)), 18) +
                RESIZE(UNSIGNED(H_REG(3)), 18)
                );

                H_TEMP_REG(1) <= STD_LOGIC_VECTOR(
                RESIZE(UNSIGNED(H_REG(4)), 18) +
                RESIZE(UNSIGNED(H_REG(5)), 18) +
                RESIZE(UNSIGNED(H_REG(6)), 18) +
                RESIZE(UNSIGNED(H_REG(7)), 18)
                );

                L_TEMP_REG(0) <= STD_LOGIC_VECTOR(
                RESIZE(UNSIGNED(L_REG(0)), 18) +
                RESIZE(UNSIGNED(L_REG(1)), 18) +
                RESIZE(UNSIGNED(L_REG(2)), 18) +
                RESIZE(UNSIGNED(L_REG(3)), 18)
                );

                L_TEMP_REG(1) <= STD_LOGIC_VECTOR(
                RESIZE(UNSIGNED(L_REG(4)), 18) +
                RESIZE(UNSIGNED(L_REG(5)), 18) +
                RESIZE(UNSIGNED(L_REG(6)), 18) +
                RESIZE(UNSIGNED(L_REG(7)), 18)
                );

            END IF;

            IF EN_D2 = '1' THEN

                -- 3clk
                H_SUM_REG <= STD_LOGIC_VECTOR(
                    RESIZE(UNSIGNED(H_TEMP_REG(0)), 19) +
                    RESIZE(UNSIGNED(H_TEMP_REG(1)), 19)
                    );

                L_SUM_REG <= STD_LOGIC_VECTOR(
                    RESIZE(UNSIGNED(L_TEMP_REG(0)), 19) +
                    RESIZE(UNSIGNED(L_TEMP_REG(1)), 19)
                    );

            END IF;
        END IF;
    END PROCESS;

    H_sum <= STD_LOGIC_VECTOR(
        RESIZE(UNSIGNED(H_SUM_REG), 19) +
        RESIZE(UNSIGNED(L_SUM_REG(18 DOWNTO 16)), 19)
    );
    L_sum <= "000" & L_SUM_REG(15 DOWNTO 0);

END Behavioral;