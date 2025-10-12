library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity spi_controller is
  port ( CLK         : in  std_logic;
         RST         : in  std_logic;
         DATA_SPI_OK : in  std_logic;
         DATA_SPI    : in  std_logic_vector (8 downto 0);
         D_C         : out std_logic;
         CS          : out std_logic;
         SDIN        : out std_logic;
         SCLK        : out std_logic;
         END_SPI     : out std_logic);
end spi_controller;


architecture rtl of spi_controller is
    -- Registro datos DATA SPI
    signal DATA_SPI_REG : std_logic_vector(7 downto 0);
    -- DC temporal que es el MSB
    signal D_C_REG : std_logic;
    -- Salida del multiplexor
    signal Q_MUX : std_logic;
    -- Clock Enable
    signal CE : std_logic;
    -- Salida del contador
    signal Q_CONT : std_logic_vector(3 downto 0) := "0000";
    -- Salida del Biestable D
    signal Q_D : std_logic;
    -- Constante para el prescaler
    constant N1 : integer := 21; -- Es puesto 3 * 7 = 21
    signal COUNTER_REG : integer range 0 to N1-1 := 0;
    signal FC : std_logic; -- Salida del prescaler que equivale al CE del contador
    -- Auxiliar del SCLK
    signal SCLK_AUX : std_logic;
    -- BUSY señal para indicar que hay dato
    signal BUSY : std_logic;
    -- Auxiliar de END_SPI
    signal END_SPI_AUX : std_logic;
begin
    -- Registro de Desplazamiento 1
    process(CLK, RST)   
        begin
            if RST = '1' then
                DATA_SPI_REG <= (others => '0'); -- RST implica poner todo a 0
            elsif CLK'event and CLK = '0' then 
                if DATA_SPI_OK = '1' then
                    -- Entran 8 bits al registro y el de más peso a DC
                    DATA_SPI_REG <= DATA_SPI(7 downto 0);
                    D_C_REG <= DATA_SPI(8);  
                end if;  
            end if;    
    end process;
    D_C <= D_C_REG;

    -- Multiplexor de 8 entradas y una salida
    process (Q_CONT, DATA_SPI_REG)
        begin
           case Q_CONT is
              when "0000" => Q_MUX <= DATA_SPI_REG(7);
              when "0001" => Q_MUX <= DATA_SPI_REG(6);
              when "0010" => Q_MUX <= DATA_SPI_REG(5);
              when "0011" => Q_MUX <= DATA_SPI_REG(4);
              when "0100" => Q_MUX <= DATA_SPI_REG(3);
              when "0101" => Q_MUX <= DATA_SPI_REG(2);
              when "0110" => Q_MUX <= DATA_SPI_REG(1);
              when "0111" => Q_MUX <= DATA_SPI_REG(0);
              when others => Q_MUX <= '0'; -- Si ninguno devolver 0
           end case;
    end process;
    
    -- Biestable D
    process (CLK, RST)
        begin
            if RST = '1' then
                Q_D <= '0';
            elsif CLK'event and CLK = '0' then
                if Q_CONT = "1000" then
                    Q_D <= '0';
                else
                    Q_D <= Q_MUX;
                end if;
            end if;    
    end process;
    SDIN <= Q_D;
    
    -- Prescaler
    process (CLK, RST)
        begin 
            if RST = '1' then
                COUNTER_REG <= 0;
                FC <= '0';
            elsif CLK'event and CLK = '0' then
                if BUSY = '1' then
                    if COUNTER_REG = N1-1 then
                        COUNTER_REG <= 0;
                        FC <= '1';
                    else
                        COUNTER_REG <= COUNTER_REG + 1;
                        FC <= '0';
                    end if;
                end if;
            end if;
    end process;
    
    -- Circuito Combinacional CE
    CE <= '1' when FC = '1' and SCLK_AUX = '0' else '0';
    
    -- Contador de 4 bits para que alcance el 9
    process (CLK, RST)
        begin
            if RST = '1' then
                Q_CONT <= (others => '0'); 
            elsif CLK'event and CLK = '0' then
                if CE = '1' then                       
                    Q_CONT <= std_logic_vector(unsigned(Q_CONT) + 1);
                elsif Q_CONT = "1000" then
                    if BUSY = '1' then -- cuando llegue a 9 y este busy 
                        Q_CONT <= (others => '0'); --Reinicia el contador
                    end if;
                end if;
            end if;
    end process;
    
    -- Circuito combinacional SCLK
    process (CLK, RST)
        begin
            if RST = '1' then
                SCLK_AUX <= '0';
            elsif CLK'event and CLK = '0' then
                if Q_CONT = "1000" then
                    SCLK_AUX <= '1';
                elsif BUSY = '1' then
                    if FC = '1' then
                        SCLK_AUX <= not SCLK_AUX;
                    end if;
                end if;
            end if;
    end process;
    SCLK <= SCLK_AUX;
    
    
    
    -- Circuito Secuencial BUSY
    process (CLK, RST)
        begin
            if RST = '1' then
                BUSY <= '0';
            elsif CLK'event and CLK = '0' then
                if DATA_SPI_OK = '1' then
                    BUSY <= '1';
                else
                    if Q_CONT = "1000" and CE = '0' then
                        BUSY <= '0';
                    end if;
                end if;
            end if;
    end process;
    
    -- Circuito Combinacional CS
    CS <= not BUSY;
    
    -- Circuito Combinacional END_SPI
    END_SPI <= '1' when Q_CONT = "1000" else '0';
  
end rtl;

