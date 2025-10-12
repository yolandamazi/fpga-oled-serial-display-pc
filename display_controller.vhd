library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity display_controller is
  port(RST        : in  std_logic;
       CLK        : in  std_logic;
       DATO_RX_OK : in  std_logic;
       DATO_RX    : in  std_logic_vector(7 downto 0);
       DP         : out std_logic;
       SEG_AG     : out std_logic_vector(6 downto 0);  -- gfedcba
       AND_70     : out std_logic_vector(7 downto 0));
end display_controller;

architecture rtl of display_controller is
    -- Salida del registro de desplazamiento 1
    signal DATO_RX_REG : std_logic_vector(31 downto 0);
    -- Selector del multiplexor
    signal SELECTOR : std_logic_vector(2 downto 0);
    -- Salida del multiplexor 8:1
    signal Q_MUX : std_logic_vector(3 downto 0);
    -- LEDs del display
    signal LEDS_DISPLAY : std_logic_vector(6 downto 0);
    -- Contador en el prescaler
    --constant CTE_ANDS : integer := 75000; -- Para implementacion, descarga en placa de TaD ms a ns
    constant CTE_ANDS : integer := 150; -- Para simulacion, puesto 3 * 50 = 150 CLKs
    signal COUNTER_REG : integer range 0 to CTE_ANDS-1 := 0;
    signal PRE_OUT : std_logic; -- Salida del prescaler que equivale al CE del contador
    -- Salida del Decodificador
    signal Q_DEC : std_logic_vector(7 downto 0);
    -- Salida del CC que corresponde con el DP
    signal DP_NEXT : std_logic;
begin
    -- Registro de Desplazamiento 1
    process(CLK, RST)   
    begin
        if RST = '1' then
            DATO_RX_REG <= (others => '0'); -- RST implica poner todo a 0
        elsif CLK'event and CLK = '1' then 
            if DATO_RX_OK = '1' then
                -- Entran 8 bits nuevos desde el LSB y deben salir 31-0 bits (31-8=23)
                DATO_RX_REG <= DATO_RX_REG(23 downto 0) & DATO_RX; 
            end if;  
        end if;    
    end process; 

    -- Multiplexor de 8 entradas y 1 salida
    process (SELECTOR, DATO_RX_REG)
    begin
       case SELECTOR is
          when "000" => Q_MUX <= DATO_RX_REG(3 downto 0);
          when "001" => Q_MUX <= DATO_RX_REG(7 downto 4);
          when "010" => Q_MUX <= DATO_RX_REG(11 downto 8);
          when "011" => Q_MUX <= DATO_RX_REG(15 downto 12);
          when "100" => Q_MUX <= DATO_RX_REG(19 downto 16);
          when "101" => Q_MUX <= DATO_RX_REG(23 downto 20);
          when "110" => Q_MUX <= DATO_RX_REG(27 downto 24);
          when "111" => Q_MUX <= DATO_RX_REG(31 downto 28);
          when others => Q_MUX <= (others => '0'); -- Si ninguno devolver 0
       end case;
    end process;

    -- Decodificador hex a 7 segmentos, activos a 0
    with Q_MUX SELect
        LEDS_DISPLAY <= "1111001" when "0001",   --1
                        "0100100" when "0010",   --2
                        "0110000" when "0011",   --3
                        "0011001" when "0100",   --4
                        "0010010" when "0101",   --5
                        "0000010" when "0110",   --6
                        "1111000" when "0111",   --7
                        "0000000" when "1000",   --8
                        "0010000" when "1001",   --9
                        "0001000" when "1010",   --A
                        "0000011" when "1011",   --b
                        "1000110" when "1100",   --C
                        "0100001" when "1101",   --d
                        "0000110" when "1110",   --E
                        "0001110" when "1111",   --F
                        "1000000" when others;   --0
    
    -- Registro para SEG_AG
    process (CLK, RST)
    begin
        if RST = '1' then
            SEG_AG <= (others => '0');
        elsif CLK'event and CLK = '1' then
            SEG_AG <= LEDS_DISPLAY;
        end if;
    end process;
    
    -- Prescaler
    process (CLK, RST)
    begin 
        if RST = '1' then
          COUNTER_REG <= 0;
          PRE_OUT <= '0';
        elsif CLK'event and CLK = '1' then
          if COUNTER_REG = CTE_ANDS-1 then
            COUNTER_REG <= 0;
            PRE_OUT <= '1';
          else
            COUNTER_REG <= COUNTER_REG + 1;
            PRE_OUT <= '0';
          end if;
        end if;
    end process;
    
    -- Contador
    process (CLK, RST)
    begin
        if RST = '1' then
            SELECTOR <= (others => '0'); 
        elsif CLK'event and CLK ='1' then
            if PRE_OUT = '1' then
                if SELECTOR = "111" then
                    SELECTOR <= "000"; --Reinicia el contador
                else
                    SELECTOR <= std_logic_vector(unsigned(SELECTOR) + 1);
                end if;
            end if;
        end if;
    end process;
    
    -- Decodificador
    process(CLK, RST)
    begin
        if RST = '1' then
            Q_DEC <= "00000000";
        elsif CLK'event and CLK = '1' then
            case SELECTOR is
                when "000" => Q_DEC <= "11111110";
                when "001" => Q_DEC <= "11111101";
                when "010" => Q_DEC <= "11111011";
                when "011" => Q_DEC <= "11110111";
                when "100" => Q_DEC <= "11101111";
                when "101" => Q_DEC <= "11011111";
                when "110" => Q_DEC <= "10111111";
                when "111" => Q_DEC <= "01111111";
                when others => Q_DEC <= "11111111";
             end case;
        end if;
    end process;
    
    -- Registro del decodificador
    process (CLK, RST)
    begin
        if RST = '1' then
            AND_70 <= (others => '1'); -- Se activa
        elsif CLK'event and CLK = '1' then
            AND_70 <= Q_DEC;
        end if;
    end process;
    
    -- Circuito Combinacional
    process (CLK, RST)
    begin
        if RST = '1' then
            DP_NEXT <= '1'; -- 1 implica desactivado
        elsif CLK'event and CLK = '1' then
            if SELECTOR = "010" or SELECTOR = "100" or SELECTOR = "110" then
                DP_NEXT <= '0';  
            else
                DP_NEXT <= '1';
            end if;
        end if;
    end process;
    
    -- Registro del Circuito Combinacional
    process (CLK, RST)
    begin
        if RST = '1' then
            DP <= '1';
        elsif CLK'event and CLK = '1' then
            DP <= DP_NEXT;
        end if;
    end process;
    
end;
