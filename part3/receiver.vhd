library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity receiver is
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    rx          : in  std_logic;
    dato_rx     : out std_logic_vector(7 downto 0);
    error_recep : out std_logic;
    DATO_RX_OK  : out std_logic);
end receiver;

architecture rtl of receiver is
    -- Registro Muestras + RX 
    signal MUESTRAS : std_logic_vector(15 downto 0);
    -- Senal de muestras listas
    signal MUESTRAS_LISTAS : std_logic;
    -- Salida Prescaler
    signal Q_PRESCALER : std_logic;
    -- Constante para el prescaler ; Tbit = 4,34microsecs = 4340ns ; 16 muestras ; 4340/16/10 = 27 CLKs
    -- 270ns entre cada activacion de Q_prescaler
    constant T_smp : integer := 27;
    signal COUNTER_REG : integer range 0 to T_smp := 0;
    -- Contadores de 1s
    signal CONT_1s : integer := 0;
    -- Contador de muestras max 16
    signal CONT_MUESTRAS : integer := 0;
    -- Maquina de estados
    type FSM is (IDLE, RECEIVING, VERIFYING, OUTPUTING);
    signal actual_state, next_state : FSM;
    -- Registro Bits Trama
    signal BITS_REG : std_logic_vector(10 downto 0);
    -- Contador de bits
    signal CONT_BITS : integer := 0;
    -- Error de recepcion
    signal ERROR : std_logic;
    -- Registro de DATO_RX_OK
    signal DATO_RX_OK_REG : std_logic;
begin
    -- Registro de Desplazamiento 1
    process(CLK, RST)   
        begin
            if RST = '1' then
                MUESTRAS <= (others => '0'); -- RST implica poner todo a 0
            elsif CLK'event and CLK = '1' then
                 if Q_PRESCALER = '1' then 
                    MUESTRAS <= MUESTRAS(14 downto 0) & RX; --RX será 0 cuando se inicie la transmisión
                 end if;
            end if;    
    end process;

    -- Prescaler
    process (CLK, RST)
        begin 
            if RST = '1' then
                COUNTER_REG <= 0;
                Q_PRESCALER <= '0';
            elsif CLK'event and CLK = '1' then
                if actual_state = RECEIVING then
                    if COUNTER_REG = T_smp-1 then
                        COUNTER_REG <= 0;
                        Q_PRESCALER <= '1';
                    else
                        COUNTER_REG <= COUNTER_REG + 1;
                        Q_PRESCALER <= '0';
                    end if;
                else
                    COUNTER_REG <= 0;
                    Q_PRESCALER <= '0';
                end if;
            end if;
    end process;
    
    -- Contador
    process (CLK, RST)
        begin
            if RST = '1' then
                CONT_MUESTRAS <= 0; 
            elsif CLK'event and CLK ='1' then
                if actual_state = RECEIVING then
                    if Q_PRESCALER = '1' then
                        if CONT_MUESTRAS = 15 then
                            CONT_MUESTRAS <= 0; --Reinicia el contador
                        else
                            CONT_MUESTRAS <= CONT_MUESTRAS + 1;
                        end if;
                    end if;
                else    
                    CONT_MUESTRAS <= 0;
                end if;
            end if;
    end process;
    
    -- Circuito Combinacional : Pulso para indicar fin de toma de muestras
    MUESTRAS_LISTAS <= '1' when (Q_PRESCALER = '1' and CONT_MUESTRAS = 15) else '0';
    
    -- Contador 1s
    process (MUESTRAS, MUESTRAS_LISTAS)
        variable contador : integer := 0;
    begin
        if MUESTRAS_LISTAS = '1' then
            contador := 0;
                for i in MUESTRAS'range loop
                    if MUESTRAS(i) = '1' then
                        contador := contador + 1;
                    end if;
                end loop;
            CONT_1s <= contador;
        end if;
    end process;

    -- Registro de los bits
    process (CLK, RST)
        begin
            if RST = '1' then
                BITS_REG <= (others => '0');
            elsif CLK'event and CLK = '1' then
                if actual_state = RECEIVING then
                    if MUESTRAS_LISTAS = '1' then
                        if CONT_1s > 9 then
                            BITS_REG <= '1' & BITS_REG(10 downto 1);
                        else
                            BITS_REG <= '0' & BITS_REG(10 downto 1);
                        end if;
                    end if;
                elsif actual_state = IDLE then
                    BITS_REG <= (others => '0');
                end if;
            end if;
    end process;

    -- Contador de bits (B0, B1, B2,...)
    process(CLK, RST)
        begin
        if RST = '1' then
            CONT_BITS <= 0;
        elsif CLK'event and CLK = '1' then
            if actual_state = RECEIVING then
                if MUESTRAS_LISTAS = '1' then
                    if CONT_BITS = 10 then
                        CONT_BITS <= 0;
                    else
                        CONT_BITS <= CONT_BITS + 1;
                    end if;
                end if;
            else
                CONT_BITS <= 0;
            end if;
        end if;
    end process;

    -- Verificador de datos
    process(RST, CLK, BITS_REG)
        variable PARIDAD : std_logic;
    begin
        if RST = '1' then
            ERROR <= '0';
        elsif CLK'event and CLK = '1' then
            if actual_state = VERIFYING then
                if MUESTRAS_LISTAS = '1' then
                    if CONT_BITS = 10 then
                        PARIDAD := '0';
                        for i in 9 downto 2 loop
                            PARIDAD := PARIDAD xor BITS_REG(i);
                        end loop;
                        
                        -- Comprobar start, stop y paridad
                        if (BITS_REG(10) = '0') and (BITS_REG(0) = '1') and (BITS_REG(1) = PARIDAD) then
                            ERROR <= '0';
                        else
                            ERROR <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- FSM : Calculo prox estado (Combinacional)
    process (actual_state, RX, CONT_BITS, ERROR) --Todas las entradas forman parte de la lista de sensibilidad
        begin
            next_state <= actual_state;
            
            case actual_state is
                when IDLE => 
                    if RX = '0' then
                        next_state <= RECEIVING;
                    end if;
                when RECEIVING =>
                    if CONT_BITS = 10 then
                        next_state <= VERIFYING;
                    end if;
                when VERIFYING =>
                    if ERROR = '1' then
                        next_state <= IDLE;
                        error_recep <= '1';
                    else
                        next_state <= OUTPUTING;
                        error_recep <= '0';
                    end if;
                when OUTPUTING =>
                    if RX = '1' then
                        next_state <= IDLE;
                    end if; 
                when others =>
                    next_state <= IDLE;
            end case;
    end process;

    -- FSM : Registro (Secuencial)
    process (CLK, RST)
        begin
            if RST = '1' then
                actual_state <= IDLE;
            elsif CLK'event and CLK = '1' then
                actual_state <= next_state;
            end if;
    end process;

    -- FSM : Calculo de las salidas (Combinacional)
    process (actual_state, RX, CONT_BITS, ERROR) --Todas las entradas forman parte de la lista de sensibilidad
        begin
            case actual_state is
                when OUTPUTING => 
                    if ERROR = '0' then
                        DATO_RX_OK_REG <= '1';
                    else
                        DATO_RX_OK_REG <= '0';
                    end if;
                when others =>
                    DATO_RX_OK_REG <= '0';
            end case; 
    end process;
    
    process (CLK, RST)
        begin
            if RST = '1' then
                DATO_RX_OK <= '0';
            elsif CLK'event and CLK = '1' then
                DATO_RX_OK <= DATO_RX_OK_REG;
            end if;
    end process;
    
    -- Registro de desplazamiento : DATO_RX
    process (CLK, RST)
        begin
            if RST = '1' then
                DATO_RX <= (others => '0');
            elsif CLK'event and CLK = '1' then
                if DATO_RX_OK_REG = '1' then
                    DATO_RX <= BITS_REG(9 downto 2);
                end if;
            end if;
    end process;

end rtl;
