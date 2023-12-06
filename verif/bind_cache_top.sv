
bind top checker_cache_top chk_cache_top(

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
  .miss(miss)
);