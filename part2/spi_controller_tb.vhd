-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

-------------------------------------------------------------------------------

entity spi_controller_tb is

end spi_controller_tb;

-------------------------------------------------------------------------------

architecture sim of spi_controller_tb is


  signal CLK_i         : std_logic                     := '0';
  signal RST_i         : std_logic                     := '1';
  signal DATA_SPI_OK_i : std_logic                     := '0';
  signal DATA_SPI_i    : std_logic_vector (8 downto 0) := (others => '0');

  signal   D_C_i     : std_logic;
  signal   CS_i      : std_logic;
  signal   SDIN_i    : std_logic;
  signal   SCLK_i    : std_logic;
  signal   END_SPI_i : std_logic;
  constant T_data    : time := 3570ns; --Completar : (puesto 3 * 7) = N1 * 17 flancos totales * 10ns = 3570ns
begin  -- sim

  DUT : entity work.spi_controller
    port map (
      CLK         => CLK_i,
      RST         => RST_i,
      DATA_SPI_OK => DATA_SPI_OK_i,
      DATA_SPI    => DATA_SPI_i,
      D_C         => D_C_i,
      CS          => CS_i,
      SDIN        => SDIN_i,
      SCLK        => SCLK_i,
      END_SPI     => END_SPI_i);


  SPI_DEV : entity work.spi_device
    port map (
      D_C  => D_C_i,
      CS   => CS_i,
      SDIN => SDIN_i,
      SCLK => SCLK_i);


  -- estímulos para CLK y RST
    RST_i <= '0';
    CLK_i <= not CLK_i after 5 ns; -- Completar : cada CLK es de 10ns 
--  


  process
    procedure gen_dato(dato : std_logic_vector(8 downto 0)) is
    begin
      wait until CLK_i = '0';
      DATA_SPI_i    <= dato;
      DATA_SPI_OK_i <= '1';
      wait until CLK_i = '0';
      DATA_SPI_OK_i <= '0';
      wait for T_data;
    end gen_dato;

  begin  -- process

    wait until RST_i = '0' ; --Completar : esperar a que no este en fase de RST (wait until RST = '0') antes ponia wait for...
    gen_dato('1'&x"0a");--Completar
    gen_dato('0'&x"44");--Completar
    gen_dato('0'&x"1b");--Completar
    gen_dato('1'&x"c6");--Completar
    gen_dato('1'&x"d8");--Completar
    gen_dato('0'&x"3e");--Completar
    gen_dato('1'&x"d2");--Completar
    gen_dato('0'&x"3d");--Completar
    gen_dato('1'&x"45");--Completar   

    report "fin de la simulacion" severity failure;
  end process;

end sim;

-------------------------------------------------------------------------------
