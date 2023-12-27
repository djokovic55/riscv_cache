library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity riscv_cache_controller is
	generic ( 
		index_bits                : integer := 2; -- 4 sets by default
		set_offset_bits           : integer := 2; -- 4 elements/ cache lines per set by default
		tag_bits                  : integer := 6  -- derived from default specs of address bus width (10 - 2 - 2 = 6)
		);
	port ( 
		clock                     : in std_logic;   -- main clock
		reset                     : in std_logic;   -- async reset
		flush                     : in std_logic;   -- to flush the cache data array, invalidate all lines
		rd                        : in std_logic;   -- read request from processor
		wr                        : in std_logic;   -- write request from processor
		index                     : in std_logic_vector(index_bits-1 downto 0); -- index of the address requested
		tag                       : in std_logic_vector(tag_bits-1 downto 0);   -- tag of the address requested
		ready                     : in std_logic;   -- data ready signal from memory
		loctn                     : out std_logic_vector(index_bits+set_offset_bits-1 downto 0);  -- location of data in cache data array
		refill                    : out std_logic;  -- refill signal to data array
		update                    : out std_logic;  -- update signal to data array
		read_from_mem             : out std_logic;  -- read signal to data memory
		write_to_mem              : out std_logic;  -- write signal to data memory
		mem_addr           				: out std_logic_vector(tag_bits+index_bits+set_offset_bits-1 downto 0);  -- addr of the block which will be evicted
		stall                     : out std_logic;
		-- new
		hit                       : out std_logic;
		miss                      : out std_logic;
		cache_state               : out std_logic_vector(2 downto 0)
		); -- signal to stall the processor		  
end riscv_cache_controller;


architecture behavioral of riscv_cache_controller is

	-- all internal signals
	type state_t is (IDLE, COMPARE_TAG, ALLOCATE_REFIL, ALLOCATE_UPDATE, WRITE_BACK);

	signal state_reg, state_next  : state_t := idle; -- state signal

	signal hit_reg, hit_next      : std_logic := '0'; -- signal to indicate hit
	signal miss_reg, miss_next    : std_logic := '0'; -- signal to indicate miss
	signal loctn_loc_reg, loctn_loc_next  : std_logic_vector(index_bits+set_offset_bits-1 downto 0); -- local for loctn

	-- user defined types
	type ram is array (0 to 2**(index_bits+set_offset_bits)-1) of std_logic_vector (tag_bits downto 0);
	type ptr_array is array (0 to 2**index_bits-1) of std_logic;

	-- instance of ram as tag array
	signal tag_array_reg, tag_array_next  : ram := (others => (others =>'0'));

	-- pointers for tree-plru algorithm
	signal s_ptr_reg, s_ptr_next          : ptr_array := (others => '0'); -- set pointer/base pointer for each set
	signal l_ptr_reg, l_ptr_next          : ptr_array := (others => '0'); -- left pointer for each set
	signal r_ptr_reg, r_ptr_next          : ptr_array := (others => '0'); -- right pointer for each set

	-- signal stall_reg, stall_next : std_logic;
	signal read_from_mem_reg, read_from_mem_next: std_logic;
	signal write_to_mem_reg, write_to_mem_next: std_logic;
	signal refill_reg, refill_next: std_logic;
	signal update_reg, update_next: std_logic;
	signal write_bck_reg, write_bck_next: std_logic;
	signal wr_req_reg, rd_req_reg : std_logic;
	signal mem_addr_reg, mem_addr_next : std_logic_vector(tag_bits+index_bits+set_offset_bits-1 downto 0);


	-- user variables
	signal temp_tag_reg, temp_tag_next         : std_logic_vector (tag_bits downto 0);
	signal index_00_reg, index_00_next 	      : std_logic_vector (index_bits+set_offset_bits-1 downto 0);
	signal index_01_reg, index_01_next 	      : std_logic_vector (index_bits+set_offset_bits-1 downto 0);
	signal index_10_reg, index_10_next 	      : std_logic_vector (index_bits+set_offset_bits-1 downto 0);
	signal index_11_reg, index_11_next 	      : std_logic_vector (index_bits+set_offset_bits-1 downto 0);

	constant IDLE_STATE : std_logic_vector(2 downto 0) := "000";
	constant COMPARE_TAG_STATE : std_logic_vector(2 downto 0) := "001";
	constant WRITE_BACK_STATE : std_logic_vector(2 downto 0) := "010";
	constant ALLOCATE_REFIL_STATE : std_logic_vector(2 downto 0) := "011";
	constant ALLOCATE_UPDATE_STATE : std_logic_vector(2 downto 0) := "100";

begin
	-- propagate state to top level
	cache_state <= IDLE_STATE when state_reg = IDLE else
								 COMPARE_TAG_STATE when state_reg = COMPARE_TAG else
								 WRITE_BACK_STATE when state_reg = WRITE_BACK else
								 ALLOCATE_REFIL_STATE when state_reg = ALLOCATE_REFIL else
								 ALLOCATE_UPDATE_STATE; 

	latch_request: process(clock, reset) begin
		if reset = '0' then
			wr_req_reg <= '0';
			rd_req_reg <= '0';
		elsif rising_edge(clock) then
			if(state_reg = IDLE) then
				wr_req_reg <= '0';
				rd_req_reg <= '0';
				if(wr = '1') then
					wr_req_reg <= '1';
				end if;

				if(rd = '1') then
					rd_req_reg <= '1';
				end if;
			end if;
		end if;
	end process;

	sequential_logic: process(clock, reset) begin
		if reset = '0' then
			-- resetting internal registers
			state_reg <= idle; 
			hit_reg   <= '0';
			miss_reg  <= '0';
			tag_array_reg <= (others => (others =>'0'));
			loctn_loc_reg <= (others => '0');
			s_ptr_reg <= (others => '0');
			l_ptr_reg <= (others => '0');
			r_ptr_reg <= (others => '0');

			temp_tag_reg <= (others => '0'); 
			index_00_reg <= (others => '0'); 
			index_01_reg <= (others => '0'); 
			index_10_reg <= (others => '0'); 
			index_11_reg <= (others => '0'); 

			-- resetting output signals	
			-- stall is not registered
			read_from_mem_reg <= '0';
			write_to_mem_reg  <= '0';
			refill_reg <= '0';
			update_reg <= '0';
			mem_addr_reg <= (others => '0');
		elsif rising_edge(clock) then
			if flush = '1' then -- high priority signal to flush entire cache
				tag_array_reg <= (others => (others => '0')); -- invalidate all cache lines
				s_ptr_reg <= (others => '0');                 -- reset all plru pointers
				l_ptr_reg <= (others => '0');
				r_ptr_reg <= (others => '0');
			else
				state_reg <= state_next; 
				hit_reg   <= hit_next;
				miss_reg  <= miss_next;
				tag_array_reg <= tag_array_next;
				loctn_loc_reg <= loctn_loc_next;
				s_ptr_reg <= s_ptr_next;
				l_ptr_reg <= l_ptr_next;
				r_ptr_reg <= r_ptr_next;
				mem_addr_reg <= mem_addr_next;


				temp_tag_reg <= temp_tag_next; 
				index_00_reg <= index_00_next; 
				index_01_reg <= index_01_next; 
				index_10_reg <= index_10_next; 
				index_11_reg <= index_11_next; 

				read_from_mem_reg <= read_from_mem_next;
				write_to_mem_reg  <= write_to_mem_next ;
				refill_reg <= refill_next;
				update_reg <= update_next;
			end if;
		end if;
	end process;

	comb_process: process(state_reg, state_next, l_ptr_reg, l_ptr_next, r_ptr_reg, r_ptr_next, s_ptr_reg, s_ptr_next, loctn_loc_reg, loctn_loc_next, read_from_mem_reg, read_from_mem_next,
												tag_array_reg, tag_array_next, temp_tag_reg, index_00_reg, index_01_reg, index_10_reg, index_11_reg, tag, rd, wr, hit_next,
												ready, refill_reg, update_reg, index, mem_addr_reg, mem_addr_next)
begin
	-- default	
	state_next <= state_reg; 
	hit_next   <= '0';
	miss_next  <= '0';
	tag_array_next <= tag_array_reg;
	loctn_loc_next <= loctn_loc_reg;
	s_ptr_next <= s_ptr_reg;
	-- BUG inferred lathces
	l_ptr_next <= l_ptr_reg;
	r_ptr_next <= r_ptr_reg;

	mem_addr_next <= mem_addr_reg;

	temp_tag_next <= temp_tag_reg; 
	index_00_next <= index_00_reg; 
	index_01_next <= index_01_reg; 
	index_10_next <= index_10_reg; 
	index_11_next <= index_11_reg; 

	-- inactive only in IDLE
	stall <= '1';
	read_from_mem_next <= '0';
	write_to_mem_next  <= '0';
	refill_next <= '0';
	update_next <= '0';

		case state_reg is		
			when IDLE  => 
			-- init state, where all requests start processing
			-- checks for hit or miss happen in this state
			-- but no read data available here (if read hit)								
				stall <= '0';

				temp_tag_next <= '0' & tag;
				index_00_next <= index & "00";
				index_01_next <= index & "01";
				index_10_next <= index & "10";
				index_11_next <= index & "11";
				
				-- state transition needed only if a read/write request is active
				if rd = '1' or wr = '1' then
					stall <= '1';
					state_next <= compare_tag; -- to hit/miss analyse state
				end if;

			when COMPARE_TAG =>
				-- determine hit or miss
				if ((temp_tag_reg(tag_bits-1 downto 0) xor tag_array_reg(to_integer(unsigned(index_00_reg)))(tag_bits-1 downto 0)) = "000000") then
					-- hit in the first way
					loctn_loc_next <= index_00_reg;								 
					hit_next  <= '1';
				elsif ((temp_tag_reg(tag_bits-1 downto 0) xor tag_array_reg(to_integer(unsigned(index_01_reg)))(tag_bits-1 downto 0)) = "000000") then
					-- hit in the second way
					loctn_loc_next <= index_01_reg;								 
					hit_next  <= '1';
				elsif ((temp_tag_reg(tag_bits-1 downto 0) xor tag_array_reg(to_integer(unsigned(index_10_reg)))(tag_bits-1 downto 0)) = "000000") then
					-- hit in the third way
					loctn_loc_next <= index_10_reg;								 
					hit_next  <= '1';
				elsif ((temp_tag_reg(tag_bits-1 downto 0) xor tag_array_reg(to_integer(unsigned(index_11_reg)))(tag_bits-1 downto 0)) = "000000") then
					-- hit in the fourth way
					loctn_loc_next <= index_11_reg;								 
					hit_next  <= '1';
				else
					-- miss occured
					miss_next <= '1';

					-- IMPORTANT reverse logic to find block location which will be evicted
					if s_ptr_reg(to_integer(unsigned(index))) = '0' then
						s_ptr_next(to_integer(unsigned(index))) <= '1';
						r_ptr_next(to_integer(unsigned(index))) <= not r_ptr_reg(to_integer(unsigned(index)));									 
						
						-- BUG comb loop
						loctn_loc_next <= index & (not(s_ptr_reg(to_integer(unsigned(index))))) & (not r_ptr_reg(to_integer(unsigned(index))));
					else
						s_ptr_next(to_integer(unsigned(index))) <= '0';
						l_ptr_next(to_integer(unsigned(index))) <= not l_ptr_reg(to_integer(unsigned(index)));

						loctn_loc_next <= index & (not(s_ptr_reg(to_integer(unsigned(index))))) & (not l_ptr_reg(to_integer(unsigned(index))));
					end if;	
				end if;		

				if(hit_next = '1') then
					-- set dirty bit
					if(wr_req_reg = '1') then
						update_next <= '1';
						tag_array_next(to_integer(unsigned(loctn_loc_next)))(tag_bits) <= '1'; 
					end if;

					-- update plru tree
					if loctn_loc_next(1) = '1' then
						s_ptr_next(to_integer(unsigned(index))) <= '1';
						r_ptr_next(to_integer(unsigned(index))) <= loctn_loc_next(0);									 

					else
						s_ptr_next(to_integer(unsigned(index))) <= '0';
						l_ptr_next(to_integer(unsigned(index))) <= loctn_loc_next(0);

					end if;	

					-- release
					stall <= '0';
					state_next <= IDLE;
				else

					-- SECTION MISS
					-- dirty bit is set
					if(tag_array_next(to_integer(unsigned(loctn_loc_next)))(tag_bits) = '1') then
						-- main memory access 
						-- write_to_mem_next <= '1';
						-- -- form addr of the evicted block to store it back to memory
						-- mem_addr_next <= tag_array_reg(to_integer(unsigned(loctn_loc_reg)))(tag_bits-1 downto 0)&loctn_loc_reg;
						----------------------------------------	
						state_next <= WRITE_BACK;
						----------------------------------------	
					else
						if(wr_req_reg = '1') then

							-- inititate cache update, because of write opp 
							update_next <= '1';
							----------------------------------------	
							state_next <= ALLOCATE_UPDATE;
							----------------------------------------	
						else 
							read_from_mem_next <= '1';
							----------------------------------------	
							state_next <= ALLOCATE_REFIL;
							----------------------------------------	
						end if;
					end if;
				end if;
			when WRITE_BACK =>
				-- main memory access 

				write_to_mem_next <= '1';
				-- form addr of the evicted block to store it back to memory
				mem_addr_next <= tag_array_reg(to_integer(unsigned(loctn_loc_reg)))(tag_bits-1 downto 0)&loctn_loc_reg;
				if(ready = '1') then
					if(rd_req_reg = '1') then

						write_to_mem_next <= '0';
						read_from_mem_next <= '1';
						mem_addr_next <= tag&loctn_loc_reg;
						refill_next <= '1';
						-- tag_array_next(to_integer(unsigned(loctn_loc_reg))) <= '0' & tag;
						----------------------------------------	
						state_next <= ALLOCATE_REFIL;
						----------------------------------------	
					elsif(wr_req_reg = '1') then
						update_next <= '1';
						----------------------------------------	
						state_next <= ALLOCATE_UPDATE;
						----------------------------------------	
					end if;
				end if;

			when ALLOCATE_REFIL =>
				-- read_from_mem <= '1';

				if(ready = '1') then
					refill_next <= '1';
					tag_array_next(to_integer(unsigned(loctn_loc_reg))) <= '0' & tag;
					-- release
					stall <= '0';
					----------------------------------------	
					state_next <= IDLE;
					----------------------------------------	
				end if;
			when ALLOCATE_UPDATE =>

				tag_array_next(to_integer(unsigned(loctn_loc_reg))) <= '1' & tag;
				-- release
				stall <= '0';
				----------------------------------------	
				state_next <= IDLE;
				----------------------------------------	
		end case;
end process;

	-- regs to output
	loctn <= loctn_loc_reg;
	refill <= refill_reg;
	update <= update_reg;
	read_from_mem <= read_from_mem_reg;
	write_to_mem <= write_to_mem_reg;
	-- write_bck <= write_bck_reg;
	mem_addr <= mem_addr_reg;

	hit <= hit_reg;
	miss <= miss_reg;

end behavioral;
