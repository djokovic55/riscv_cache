-------------------------------------------------------------------------------------------------
-- Design Name   : Test Bench to test 'Top' Module
-- Description   : This TB models a non-pipelined processor which generates memory read/write
--                 requests to the Cache Controller frequently. It is assumed that same clock
--                 drives all the modules in the test environment.
--                 CPI of the processor is assumed to be = 4 + Memory Access Cycles
-- Date          : 10-05-2019
-- Designed By   : Mitu Raj, iammituraj@gmail.in
-- Comments      : Test bench numerics are bound to changes in DUT.
-------------------------------------------------------------------------------------------------
Library IEEE;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
  
ENTITY TB_Processor IS
END TB_Processor;
 
ARCHITECTURE behavior OF TB_Processor IS 

	 -- Component Declaration for the Design Under Test (DUT)
 
    COMPONENT Top
    PORT(
         clock : IN  std_logic;
         reset : IN  std_logic;
         addr : IN  std_logic_vector(31 downto 0);
         rdata : OUT  std_logic_vector(31 downto 0);
         wdata : IN  std_logic_vector(31 downto 0);
         flush : IN  std_logic;
         rd : IN  std_logic;
         wr : IN  std_logic;
         stall : OUT  std_logic
        );
    END COMPONENT;
    
   --signal d : integer := 4;
   --Inputs
   signal clock : std_logic := '0';
   signal reset : std_logic := '0';
   signal addr : std_logic_vector(31 downto 0) := (others => '0');
   signal wdata : std_logic_vector(31 downto 0) := (others => '0');
   signal flush : std_logic := '0';
   signal rd : std_logic := '0';
   signal wr : std_logic := '0';
 
 	--Outputs
   signal rdata : std_logic_vector(31 downto 0);
   signal stall : std_logic;

   -- Clock period definitions
   constant clock_period : time := 1 us; 
	
	-- ARRAY TO STORE TEST VECTORS
	type my_array is array (0 to 15) of STD_LOGIC_VECTOR (31 downto 0);
   signal test_data : my_array := (OTHERS => (OTHERS =>'0'));
   signal test_addr : my_array := (OTHERS => (OTHERS =>'0'));	

	 
 
   ------------------- USER PROCEDURES ------------------------
	
	-- TO RESET SYSTEM 
	procedure RESET_SYS (signal reset : out std_logic) is
	begin
	   reset <= '0';
		wait for 4*clock_period;
		reset <= '1';
	end procedure;
	
	-- MODELS A LATENCY OF 4 CYCLES UNTIL THE NEXT INSTRUCTION IS DECODED
	procedure HALT (signal wr : out std_logic;
                   signal rd : out std_logic) is
	begin
	   wait for clock_period;
	   wait until clock = '1' and stall = '0';
	   wait for 1.5*clock_period; -- WAIT THEN ACKNOWLEDGE
	   wr <= '0';
		rd <= '0';		
	   wait for 4*clock_period;   -- MODELS THE LATENCY
	end procedure;
	
	-- FINISH
	procedure FINISH is
	begin
	   wait;
	end procedure;
	
	-- FLUSH INSTRUCTION
	procedure FLUSH_CACHE (signal flush : out std_logic) is
	begin
	   flush <= '1';
		wait for clock_period;
		flush <= '0';
	end procedure;
	
	-- WRITE INSTRUCTION
	procedure MEM_WR (signal tb_data : in std_logic_vector(31 downto 0);
							signal tb_addr : in std_logic_vector(31 downto 0);
							signal wdata   : out std_logic_vector(31 downto 0);
							signal addr    : out std_logic_vector(31 downto 0);
							signal wr      : out std_logic;
							signal rd      : out std_logic) is
	begin
      wdata <= tb_data;
		addr  <= tb_addr;
		wr    <= '1';
		rd	   <= '0';
   end procedure;	
	
	-- READ INSTRUCTION
	procedure MEM_RD (signal tb_addr : in std_logic_vector(31 downto 0);							
							signal addr    : out std_logic_vector(31 downto 0);
							signal wr      : out std_logic;
							signal rd      : out std_logic) is
	begin      
		addr  <= tb_addr;
		wr    <= '0';
		rd	   <= '1';
   end procedure;	
	
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: Top PORT MAP (
          clock => clock,
          reset => reset,
          addr => addr,
          rdata => rdata,
          wdata => wdata,
          flush => flush,
          rd => rd,
          wr => wr,
          stall => stall
        );
		  
	-------------- TEST VECTORS -----------------
	test_addr(0) <= x"00000201"; -- READ MISS		
	test_addr(1) <= x"00000301"; -- READ MISS		
	test_addr(2) <= x"00000311"; -- READ MISS		
	test_addr(3) <= x"00000321"; -- READ MISS		
	test_addr(4) <= x"00000331"; -- READ MISS		

	test_data(0) <= x"20202020"; -- WRITE HIT
	test_data(1) <= x"30303030"; -- WRITE HIT
	test_data(2) <= x"40404040"; -- WRITE HIT
	test_data(3) <= x"50505050"; -- WRITE HIT
	test_data(4) <= x"60606060"; -- WRITE HIT
	test_data(5) <= x"61616161"; -- WRITE HIT
	
	
  ---------------------------------------------
  
   -- Clock process definitions
   clock_process :process
   begin
		clock <= '0';
		wait for clock_period/2;
		clock <= '1';
		wait for clock_period/2;
   end process;
 
   
   -- Stimulus process
   stim_proc: process
   begin	
	
      ---------- MODELLING INSTRUCTION EXECUTION BY A PROCESSOR --------
		
		-- INITIAL OPERATIONS
		RESET_SYS(reset);
		FLUSH_CACHE(flush);
		
		-- RANDOM READ WRITE REQUESTS TO MEMORY BY PROCESSOR 		
		MEM_WR(test_data(0),test_addr(0),wdata,addr,wr,rd);	 -- write_miss LRU 3
		HALT(wr,rd);

		MEM_RD(test_addr(0),addr,wr,rd);
		HALT(wr,rd);

		MEM_WR(test_data(1),test_addr(1),wdata,addr,wr,rd);	 -- write_miss LRU 1
		HALT(wr,rd);
		
		MEM_WR(test_data(2),test_addr(2),wdata,addr,wr,rd);	 -- write_miss LRU 2
		HALT(wr,rd);

		MEM_WR(test_data(3),test_addr(3),wdata,addr,wr,rd);	 -- write_miss LRU 0
		HALT(wr,rd);

		MEM_WR(test_data(4),test_addr(4),wdata,addr,wr,rd);	 -- write_miss WB LRU 3
		HALT(wr,rd);

		MEM_WR(test_data(5),test_addr(4),wdata,addr,wr,rd);	 -- write_hit LRU 3
		HALT(wr,rd);

		MEM_RD(test_addr(0),addr,wr,rd);
		HALT(wr,rd);

		HALT(wr,rd);
		HALT(wr,rd);
		HALT(wr,rd);
		HALT(wr,rd);
		-- FLUSH AND CHECK DATA VALIDITY
		FLUSH_CACHE(flush);
		-- MEM_RD(test_addr(15),addr,wr,rd);	
		-- HALT(wr,rd);
		
		-- FINISH OPERATIONS
		FINISH;
		-----------------------------------------------------------------------
		
   end process;

END;
