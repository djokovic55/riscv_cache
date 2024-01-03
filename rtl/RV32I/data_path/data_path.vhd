library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity data_path is
   generic (DATA_WIDTH : positive := 32);
   port(
      -- ********* Globalna sinhronizacija ******************
      clk                 : in  std_logic;
      reset               : in  std_logic;
      -- ********* Interfejs ka Memoriji za instrukcije *****
      instr_mem_address_o : out std_logic_vector(31 downto 0);
      instr_mem_read_i    : in  std_logic_vector(31 downto 0);
      instruction_o       : out std_logic_vector(31 downto 0);
      -- ********* Interfejs ka Memoriji za podatke *****
      data_mem_address_o  : out std_logic_vector(31 downto 0);
      data_mem_write_o    : out std_logic_vector(31 downto 0);
      data_mem_read_i     : in  std_logic_vector(31 downto 0);
      -- ********* Kontrolni signali ************************
      mem_to_reg_i        : in  std_logic;
      alu_op_i            : in  std_logic_vector(4 downto 0);
      pc_next_sel_i       : in  std_logic;
      alu_src_i           : in  std_logic;
      rd_we_i             : in  std_logic;
      -- ********* Statusni signali *************************
      branch_condition_o  : out std_logic;
    -- ******************************************************
      stall_i             : in std_logic
      );

end entity;


architecture Behavioral of data_path is
   --**************REGISTRI*********************************   
   signal pc_reg_s, pc_next_s                   : std_logic_vector (31 downto 0);
   --********************************************************
   --**************SIGNALI***********************************
   signal instruction_s                         : std_logic_vector(31 downto 0);
   signal pc_adder_s                            : std_logic_vector(31 downto 0);
   signal branch_adder_s                        : std_logic_vector(31 downto 0);
   signal rs1_data_s, rs2_data_s, rd_data_s     : std_logic_vector (31 downto 0);
   signal immediate_extended_s, extended_data_s : std_logic_vector(31 downto 0);
   -- AlU signali   
   signal alu_zero_s, alu_of_o_s                : std_logic;
   signal b_s, a_s                              : std_logic_vector(31 downto 0);
   signal alu_result_s                          : std_logic_vector(31 downto 0);
   --Signali grananja (eng. branch signals).   
   signal bcc                                   : std_logic;
--********************************************************
begin

   --***********Sekvencijalna logika**********************   
   pc_proc : process (clk) is
   begin
      if (rising_edge(clk)) then
         if (reset = '0')then
            pc_reg_s <= (others => '0');
         elsif(stall_i = '0') then
            pc_reg_s <= pc_next_s;
         end if;
      end if;
   end process;
   --*****************************************************

   --***********Kombinaciona logika***********************
   bcc <= instruction_s(12);

   -- sabirac za uvecavanje programskog brojaca (sledeca instrukcija)
   pc_adder_s     <= std_logic_vector(unsigned(pc_reg_s) + to_unsigned(4, DATA_WIDTH));
   -- sabirac za uslovne skokove
   branch_adder_s <= std_logic_vector(unsigned(immediate_extended_s) + unsigned(pc_reg_s));

   -- Provera uslova skoka
   branch_condition_o <= '1' when a_s = b_s else
                         '0';

   -- MUX koji odredjuje sledecu vrednost za programski brojac.
   -- Ako se ne desi skok programski brojac se uvecava za 4.
   with pc_next_sel_i select
      pc_next_s <= pc_adder_s when '0',
      branch_adder_s          when others;

   -- MUX koji odredjuje sledecu vrednost za b ulaz ALU jedinice.
   b_s <= rs2_data_s when alu_src_i = '0' else
          immediate_extended_s;
   -- Azuriranje a ulaza ALU jedinice
   a_s <= rs1_data_s;

   -- MUX koji odredjuje sta se upisuje u odredisni registar(rd_data_s)
   rd_data_s <= data_mem_read_i when mem_to_reg_i = '1' else
                alu_result_s;
   --*****************************************************

   --***********Instanciranja*****************************

   --Registarska banka
   register_bank_1 : entity work.register_bank
      generic map (
         WIDTH => 32)
      port map (
         clk           => clk,
         reset         => reset,
         rd_we_i       => rd_we_i,
         rs1_address_i => instruction_s (19 downto 15),
         rs2_address_i => instruction_s (24 downto 20),
         rs1_data_o    => rs1_data_s,
         rs2_data_o    => rs2_data_s,
         rd_address_i  => instruction_s (11 downto 7),
         rd_data_i     => rd_data_s);


   -- Modul za prosirenje immediate polja instrukcije
   immediate_1 : entity work.immediate
      port map (
         instruction_i        => instruction_s,
         immediate_extended_o => immediate_extended_s
         );

   -- Aritmeticko logicka jedinica
   ALU_1 : entity work.ALU
      generic map (
         WIDTH => DATA_WIDTH)
      port map (
         a_i    => a_s,
         b_i    => b_s,
         op_i   => alu_op_i,
         res_o  => alu_result_s,
         zero_o => alu_zero_s,
         of_o   => alu_of_o_s);

   --*****************************************************

   --***********Ulazi/Izlazi******************************
   -- Ka controlpath-u
   instruction_o       <= instruction_s;
   -- Sa memorijom za instrukcije
   instruction_s       <= instr_mem_read_i;
   -- Sa memorijom za podatke
   instr_mem_address_o <= pc_reg_s;
   data_mem_address_o  <= alu_result_s;
   data_mem_write_o    <= rs2_data_s;
end architecture;


