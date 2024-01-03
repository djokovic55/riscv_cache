
bind top_riscv_system.memory_subsystem checker_cache_top chk_cache_top(

  .clock(clock),
  .reset(reset),
  .addr(addr),
  .rdata(rdata),
  .wdata(wdata),
  .flush(flush),
  .rd(rd),
  .wr(wr),
  .stall(stall),

  .hit(hit),
  .miss(miss),
	.cache_state(cache_state)
);
