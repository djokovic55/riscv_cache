
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity main_memory is
	Generic ( 
		bulk_size                 : integer := 128; -- DEFAULT SPECS, DATA WIDTH OF THE MEMORY SYSTEM
		word_size                 : integer := 32; -- DEFAULT SPECS
		addr_width                : integer := 10  -- DEFAULT SPECS
	);
	Port ( 
		clock                     : in  STD_LOGIC;   -- MEMORY CLOCK      
		reset                     : in STD_LOGIC;    -- ASYNC RESET SIGNAL    
		rd                        : in  STD_LOGIC;   -- READ SIGNAL 
		wr                        : in STD_LOGIC;	  -- WRITE SIGNAL		  
		addr                      : in  STD_LOGIC_VECTOR (addr_width-1 downto 0); -- ADDRESS INPUT
		data_in                   : in  STD_LOGIC_VECTOR (bulk_size-1  downto 0); -- DATA INPUT FOR WRITE
		data_out                  : out  STD_LOGIC_VECTOR (bulk_size-1  downto 0); -- DATA OUT FOR READ
		data_ready                : out  STD_LOGIC); -- TO ACKNOWLEDGE THE END OF DATA PROCESSING
end main_memory;

architecture Behavioral of main_memory is

-- USER DEFINED DATA TYPE
type ram is array (0 to 2**addr_width-1) of STD_LOGIC_VECTOR (word_size-1 downto 0);

-- -- FUNCTION TO FILL MEMORY WITH DEFAULT VALUES 0 TO 255 FOR LOCATIONS 0 TO 255
-- function fill_mem
-- return ram is
-- variable data_memory_temp : ram;
-- begin
-- for i in 0 to 2**addr_width-1 loop
--     data_memory_temp(i) := STD_LOGIC_VECTOR(to_unsigned(i,word_size));
-- end loop;
-- return data_memory_temp;
-- end function fill_mem;

-- INSTANCE OF DATA MEMORY
signal ram_s : ram;
signal addr_temp : std_logic_vector(addr_width-1 downto 0);
signal zero_temp: std_logic_vector(1 downto 0);

begin

zero_temp <= "00";
addr_temp <= addr(addr_width-1 downto 2)&zero_temp;

process(clock, reset)
begin
	if(reset = '0') then
		ram_s <= (others => (others => '0'));
	elsif rising_edge(clock) then    	
		if wr = '1' then
			ram_s(to_integer(unsigned(addr_temp)+3)) <= data_in(31 downto 0);  -- SYNCHRONOUS WRITE
			ram_s(to_integer(unsigned(addr_temp)+2)) <= data_in(63 downto 32);  -- SYNCHRONOUS WRITE
			ram_s(to_integer(unsigned(addr_temp)+1)) <= data_in(95 downto 64);  -- SYNCHRONOUS WRITE
			ram_s(to_integer(unsigned(addr_temp)))   <= data_in(127 downto 96);  -- SYNCHRONOUS WRITE
		end if;

		data_out(31 downto 0)   <= ram_s(to_integer(unsigned(addr_temp)+3)) ;  -- SYNCHRONOUS READ
		data_out(63 downto 32)  <= ram_s(to_integer(unsigned(addr_temp)+2)) ;  -- SYNCHRONOUS READ
		data_out(95 downto 64)  <= ram_s(to_integer(unsigned(addr_temp)+1)) ;  -- SYNCHRONOUS READ
		data_out(127 downto 96) <= ram_s(to_integer(unsigned(addr_temp))) ;  -- SYNCHRONOUS READ
	end if;
end process;

process(clock,reset)
begin
if reset = '0' then -- ACTIVE LOW ASYNC RESET
   data_ready <= '0';
elsif rising_edge(clock) then
	if wr = '1' then
		data_ready <= '1'; -- DATA IS WRITTEN, ACKNOWLDGE THE PROCESSOR
	elsif rd = '1' then
		data_ready <= '1'; -- DATA CAN BE READ, ACKNOWLEDGE THE PROCESSOR
	else
		data_ready <= '0';
	end if;
end if;
end process;

end Behavioral;

