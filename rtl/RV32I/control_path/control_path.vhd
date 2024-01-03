library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_path is
   port (clk                : in  std_logic;
         reset              : in  std_logic;
         -- ********* Interfejs za prihvat instrukcije iz datapath-a*********
         instruction_i      : in  std_logic_vector (31 downto 0);
         -- ********* Kontrolni intefejs ************************************* 
         mem_to_reg_o       : out std_logic;
         alu_op_o           : out std_logic_vector(4 downto 0);
         pc_next_sel_o      : out  std_logic;         
         alu_src_o          : out std_logic;
         rd_we_o            : out std_logic;         
         -- new
         re_o               : out std_logic;         
         --********** Ulazni Statusni interfejs **************************************
         branch_condition_i : in  std_logic;
         --********** Izlazni Statusni interfejs **************************************
         data_mem_we_o      : out std_logic_vector(3 downto 0)
         );
end entity;


architecture behavioral of control_path is
   signal alu_2bit_op_s : std_logic_vector(1 downto 0);
   signal data_mem_we_s : std_logic;
   signal branch_s: std_logic;
begin

   process (branch_condition_i, branch_s)is
   begin
      pc_next_sel_o <= '0';
      if (branch_s = '1' and branch_condition_i = '1')then
         pc_next_sel_o <= '1';
      end if;
   end process;
                    
   ctrl_dec : entity work.ctrl_decoder(behavioral)
      port map(
         opcode_i      => instruction_i(6 downto 0),
         branch_o      => branch_s,
         mem_to_reg_o  => mem_to_reg_o,
         data_mem_we_o => data_mem_we_s,
         alu_src_o     => alu_src_o,
         rd_we_o       => rd_we_o,
         -- new
         re            => re_o,
         alu_2bit_op_o => alu_2bit_op_s);

   alu_dec : entity work.alu_decoder(behavioral)
      port map(
         alu_2bit_op_i => alu_2bit_op_s,
         funct3_i      => instruction_i(14 downto 12),
         funct7_i      => instruction_i(31 downto 25),
         alu_op_o      => alu_op_o);

   --***************Izlazi************************
   data_mem_we_o <= (others => (data_mem_we_s));


end architecture;

