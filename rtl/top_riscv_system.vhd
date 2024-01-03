
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.txt_util.all;

entity top_riscv_system is
port (
  instr_code : in std_logic_vector(31 downto 0)
);
end entity;

-- test
architecture Behavioral of top_riscv_system is
   component top is
      generic ( 
         -- default specs from processor
         data_bus_width : integer := 32;
         addr_bus_width : integer := 32;
         -- default specs from cache controller
         index_bits                : integer  := 2;   
         tag_bits                  : integer  := 6;
         set_offset_bits : integer := 2;
         -- default specs from cache memory data array
         loctn_bits     : integer := 4;
         offset_bits 	  : integer := 2;   
         block_size     : integer := 128; 
         -- default specs from main memory
         bulk_size : integer := 128; 
               bank_word_size : integer := 32;  
         addr_width     : integer := 10;
               -- others	derived from above specs				  
         tag_offset     : integer := 9; -- local address --> | tag  | index | offset |
         index_offset   : integer := 3;
         block_offset   : integer := 1);
      port ( 
         clock : in std_logic; -- global clock
         reset : in std_logic; -- global async reset
         addr  : in std_logic_vector (addr_bus_width-1 downto 0);  -- address bus
         rdata : out std_logic_vector (data_bus_width-1 downto 0); -- data bus for read
         wdata : in std_logic_vector (data_bus_width-1 downto 0);  -- data bus for write
         flush : in std_logic; -- flush cache lines
         rd    : in std_logic; -- read signal from processor
         wr    : in std_logic; -- write signal from processor
         stall : out std_logic; -- stall signal to processor			  

         -- new 
         hit   : out std_logic;
         miss  : out std_logic
         );
   end component;

  component TOP_RISCV is
    generic (DATA_WIDTH : positive := 32);
    port(
        -- ********* Globalna sinhronizacija ******************
        clk                 : in  std_logic;
        reset               : in  std_logic;
        stall_i             : in  std_logic;
        -- ********* Interfejs ka Memoriji za instrukcije *****
        instr_mem_address_o : out std_logic_vector (31 downto 0);
        instr_mem_read_i    : in  std_logic_vector(31 downto 0);
        -- ********* Interfejs ka Memoriji za podatke *********
        data_mem_we_o       : out std_logic_vector(3 downto 0);
        data_mem_address_o  : out std_logic_vector(31 downto 0);
        data_mem_write_o    : out std_logic_vector(31 downto 0);
        data_mem_read_i     : in  std_logic_vector (31 downto 0);
        data_mem_re_o       : out  std_logic);

  end component;

   -- Signali memorije za instrukcije
   signal ena_instr_s, enb_instr_s     : std_logic;
   signal wea_instr_s, web_instr_s     : std_logic_vector(3 downto 0);
   signal addra_instr_s, addrb_instr_s : std_logic_vector(9 downto 0);
   signal dina_instr_s, dinb_instr_s   : std_logic_vector(31 downto 0);
   signal douta_instr_s, doutb_instr_s : std_logic_vector(31 downto 0);
   signal addrb_instr_32_s             : std_logic_vector(31 downto 0);
   -- Signali memorije za podatke
   signal ena_data_s, enb_data_s       : std_logic;
   signal wea_data_s, web_data_s       : std_logic_vector(3 downto 0);
   signal addra_data_s, addrb_data_s   : std_logic_vector(9 downto 0);
   signal dina_data_s, dinb_data_s     : std_logic_vector(31 downto 0);
   signal douta_data_s, doutb_data_s   : std_logic_vector(31 downto 0);
   signal addra_data_32_s              : std_logic_vector(31 downto 0);

   -- new
   signal re_data_s                    : std_logic;
   signal stall_s                      : std_logic;



begin

  addra_data_s <= addra_data_32_s(9 downto 0);

  -- Memory sybsystem
  memory_subsystem: top
  port map(
  clock => clk,
  reset => reset,
  addr => std_logic_vector(to_unsigned(0,22))&addra_data_s,
  rdata => douta_data_s,
  wdata => dina_data_s,
  flush => '0',
  rd => re_data_s,
  wr => wea_data_s(0),
  -- stall because mem access requires more than 1 cycle
  stall => stall_s,

  -- new 
  hit => open,
  miss => open

  );


   -- Top Modul - RISCV procesor jezgro
  riscv : entity work.TOP_RISCV
  port map (
    clk   => clk,
    reset => reset,
    stall_i => stall_s,

    instr_mem_read_i    => instr_code,
    instr_mem_address_o => open,

    data_mem_we_o      => wea_data_s,
    data_mem_address_o => addra_data_32_s,
    data_mem_read_i    => douta_data_s,
    data_mem_write_o   => dina_data_s,
    -- new
    data_mem_re_o        => re_data_s);

end architecture;