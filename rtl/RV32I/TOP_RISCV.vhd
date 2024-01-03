library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity TOP_RISCV is
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

end entity;

architecture structural of TOP_RISCV is
   signal instruction_s      : std_logic_vector(31 downto 0);
   signal mem_to_reg_s       : std_logic;
   signal alu_op_s           : std_logic_vector (4 downto 0);
   signal alu_src_s          : std_logic;
   signal re_s               : std_logic;
   signal rd_we_s            : std_logic;
   signal branch_condition_s : std_logic;
   signal pc_next_sel_s      : std_logic;
begin

   data_path_1 : entity work.data_path
      generic map (
         DATA_WIDTH => DATA_WIDTH)
      port map (
         clk                 => clk,
         reset               => reset,
         instr_mem_address_o => instr_mem_address_o,
         instr_mem_read_i    => instr_mem_read_i,
         instruction_o       => instruction_s,
         data_mem_address_o  => data_mem_address_o,
         data_mem_write_o    => data_mem_write_o,
         data_mem_read_i     => data_mem_read_i,
         mem_to_reg_i        => mem_to_reg_s,
         alu_op_i            => alu_op_s,
         pc_next_sel_i       => pc_next_sel_s,
         alu_src_i           => alu_src_s,
         rd_we_i             => rd_we_s,
         stall_i             => stall_i,
         branch_condition_o  => branch_condition_s);

   control_path_1 : entity work.control_path
      port map (
         clk                => clk,
         reset              => reset,
         instruction_i      => instruction_s,
         mem_to_reg_o       => mem_to_reg_s,
         alu_op_o           => alu_op_s,
         pc_next_sel_o      => pc_next_sel_s,
         alu_src_o          => alu_src_s,
         rd_we_o            => rd_we_s,
         -- new 
         re_o => re_s,
         branch_condition_i => branch_condition_s,
         data_mem_we_o      => data_mem_we_o);
   --************************************
   -- new
   data_mem_re_o <= re_s;

end architecture;


