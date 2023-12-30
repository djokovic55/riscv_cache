
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Cache_Memory_Data_Array is
	Generic ( 
		loctn_bits                : integer := 4;   -- 16 ENTRIES, DEFAULT SPECS
		offset_bits               : integer := 2;   -- TO CHOOSE A WORD FROM A BLOCK SIZE = 4 MEMORY WORDS, DEFAULT SPECS
		block_size                : integer := 128; -- DEFAULT SPECS, = DATA BUS WIDTH OF THE MEMORY SYSTEM
		mem_word_size             : integer := 32;  -- WORD SIZE OF MEMORY BANKS, DEFAULT SPECS
		proc_word_size            : integer := 32;  -- WORD SIZE FOR OUR PROCESSOR DATA BUS, DEFAULT SPECS
		blk_0_offset              : integer   := 127; -- CACHE BLOCK ---> |BLOCK 0 | BLOCK 1 | BLOCK 2| BLOCK 3|
		blk_1_offset              : integer   := 95;
		blk_2_offset              : integer   := 63;
		blk_3_offset              : integer   := 31);
	Port ( 
		clock                     : in STD_LOGIC; -- CACHE CLOCK SAME AS PROCESSOR CLOCK      
		refill                    : in STD_LOGIC; -- MISS, REFILL CACHE USING DATA FROM MEMORY
		update                    : in STD_LOGIC; -- HIT, UPDATE CACHE USING DATA FROM PROCESSOR
		index                     : in STD_LOGIC_VECTOR (loctn_bits-1 downto 0);      -- INDEX SELECTION
		offset                    : in STD_LOGIC_VECTOR (offset_bits-1 downto 0);     -- OFFSET SELECTION
		data_from_mem             : in STD_LOGIC_VECTOR (block_size-1 downto 0);      -- DATA FROM MEMORY
		write_back_data           : out STD_LOGIC_VECTOR (block_size-1 downto 0);     -- evicted block data in case of a write miss 
		write_data                : in STD_LOGIC_VECTOR (proc_word_size-1 downto 0);  -- DATA FROM PROCESSOR
		read_data                 : out STD_LOGIC_VECTOR(proc_word_size-1 downto 0)); -- DATA TO PROCESSOR			  
end Cache_Memory_Data_Array;

architecture Behavioral of Cache_Memory_Data_Array is

-- USER DEFINED DATA TYPE
-- CONTIGUOUS MEMORY OF WORD-SIZE DATA.
type ram is array (0 to 2**(loctn_bits+offset_bits)-1) of STD_LOGIC_VECTOR (mem_word_size-1 downto 0);

-- INSTANCE OF CACHE MEMORY
signal cache_memory : ram := (OTHERS => (OTHERS =>'0'));

signal v0 : STD_LOGIC_VECTOR (loctn_bits+offset_bits-1 downto 0);
signal v1 : STD_LOGIC_VECTOR (loctn_bits+offset_bits-1 downto 0);
signal v2 : STD_LOGIC_VECTOR (loctn_bits+offset_bits-1 downto 0);
signal v3 : STD_LOGIC_VECTOR (loctn_bits+offset_bits-1 downto 0);
signal v4 : STD_LOGIC_VECTOR (loctn_bits+offset_bits-1 downto 0);

begin

	v0 <= index & offset; 
	v1 <= index & "00";
	v2 <= index & "01";
	v3 <= index & "10";
	v4 <= index & "11";	

	process(clock)
	begin
	-- index here means set plus way location
	if rising_edge(clock) then   
	  if update = '1' then    -- HIT, UPDATE CACHE BLOCK USING WORD FROM PROCESSOR	
		  cache_memory(to_integer(unsigned(v0))) <= write_data; 
	  elsif refill = '1' then -- READ MISS, REFILL CACHE BLOCK USING DATA BLOCK FROM MEMORY		   
		  cache_memory(to_integer(unsigned(v1))) <= data_from_mem(blk_0_offset downto blk_1_offset+1);
		  cache_memory(to_integer(unsigned(v2))) <= data_from_mem(blk_1_offset downto blk_2_offset+1);
		  cache_memory(to_integer(unsigned(v3))) <= data_from_mem(blk_2_offset downto blk_3_offset+1);
		  cache_memory(to_integer(unsigned(v4))) <= data_from_mem(blk_3_offset downto 0);
	  end if;	
	  read_data <= cache_memory(to_integer(unsigned(v0))); -- READ WORD FROM CACHE, ALWAYS AVAILABLE

	  -- write back data, always available
	  write_back_data(blk_0_offset downto blk_1_offset+1) <= cache_memory(to_integer(unsigned(v1)));
	  write_back_data(blk_1_offset downto blk_2_offset+1) <= cache_memory(to_integer(unsigned(v2)));
	  write_back_data(blk_2_offset downto blk_3_offset+1) <= cache_memory(to_integer(unsigned(v3)));
	  write_back_data(blk_3_offset downto 0)              <= cache_memory(to_integer(unsigned(v4)));
	end if;
	end process;

end Behavioral;

