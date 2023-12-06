library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
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
		stall : out std_logic -- stall signal to processor			  
		);
end top;

architecture Behavioral of top is

-- interconnect signals
signal addr_local : std_logic_vector (addr_width-1 downto 0); -- locally addressable memory space

-- for main memory connections
signal ready_inter         : std_logic;
signal data_from_mem_inter : std_logic_vector (block_size-1 downto 0);  
signal write_back_data_inter : std_logic_vector (block_size-1 downto 0);  
signal rd_inter_mem        : std_logic;
signal wr_inter_mem        : std_logic;
signal addr_s   : std_logic_vector(tag_bits+index_bits+set_offset_bits-1 downto 0);

-- for cache data array connections
signal refill_inter       : std_logic;
signal update_inter       : std_logic;
signal index_inter        : std_logic_vector (index_bits+set_offset_bits-1 downto 0);

-- sub modules
component riscv_cache_controller
	port ( 
		clock                     : in std_logic; 
		reset                     : in std_logic; 
		flush                     : in std_logic; 
		rd                        : in std_logic; 
		wr                        : in std_logic; 
		index                     : in std_logic_vector (index_bits-1 downto 0); 
		tag                       : in std_logic_vector (tag_bits-1 downto 0);   
		ready                     : in std_logic;  
		loctn                     : out std_logic_vector(index_bits+set_offset_bits-1 downto 0); 			  
		refill                    : out std_logic;    
		update                    : out std_logic;    
		read_from_mem             : out std_logic;    
		mem_addr                  : out std_logic_vector(tag_bits+index_bits+set_offset_bits-1 downto 0);  -- addr of the block which will be evicted
		write_to_mem              : out std_logic;    
		stall                     : out std_logic);		
end component;

component cache_memory_data_array
	port ( 
		clock                     : in std_logic;      
		refill                    : in std_logic; 
		update                    : in std_logic; 
		index                     : in std_logic_vector (loctn_bits-1 downto 0);      
		offset                    : in std_logic_vector (offset_bits-1 downto 0);     
		data_from_mem             : in std_logic_vector (block_size-1 downto 0);      
		write_back_data           : out std_logic_vector (block_size-1 downto 0);     -- evicted block data in case of a write miss 
		write_data                : in std_logic_vector (data_bus_width-1 downto 0);  
		read_data                 : out std_logic_vector(data_bus_width-1 downto 0)); 	
end component;

component main_memory is
	port ( 
		clock                     : in  std_logic;   -- memory clock      
		reset                     : in std_logic;    -- async reset signal    
		rd                        : in  std_logic;   -- read signal 
		wr                        : in std_logic;	  -- write signal		  
		addr                      : in  std_logic_vector (addr_width-1 downto 0); -- address input
		data_in                   : in  std_logic_vector (bulk_size-1  downto 0); -- data input for write
		data_out                  : out  std_logic_vector (bulk_size-1  downto 0); -- data out for read
		data_ready                : out  std_logic); -- to acknowledge the end of data processing
end component;

begin

addr_local <= addr(addr_width-1 downto 0);

--instantiating sub modules
inst_cache_controller: riscv_cache_controller port map(
		clock                      => clock,
		reset                      => reset,
		flush                      => flush,
		rd                         => rd,
		wr                         => wr,
		index                      => addr_local(index_offset downto block_offset+1),
		tag                        => addr_local(tag_offset downto index_offset+1),
		ready                      => ready_inter,
		loctn                      => index_inter,
		refill                     => refill_inter,
		update                     => update_inter,
		read_from_mem              => rd_inter_mem,
		write_to_mem               => wr_inter_mem,
		-- new
		mem_addr                   => addr_s,
		stall                      => stall
	);

inst_cache_memory_data_array: cache_memory_data_array port map(
		clock                      => clock,
		refill                     => refill_inter,
		update                     => update_inter,
		index                      => index_inter,
		offset                     => addr_local(block_offset downto 0),
		data_from_mem              => data_from_mem_inter ,
		write_back_data            => write_back_data_inter,
		write_data                 => wdata,
		read_data                  => rdata
	);

inst_main_memory_system: main_memory port map(
		clock                      => clock,
		reset                      => reset,
		rd                         => rd_inter_mem,
		wr                         => wr_inter_mem,
		-- new
		addr                       => addr_s,
		data_in                    => write_back_data_inter,
		data_out                   => data_from_mem_inter,
		data_ready                 => ready_inter
	);

end Behavioral;

