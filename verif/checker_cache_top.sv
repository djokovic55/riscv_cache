
checker  checker_top(
  clock,
  reset,
  addr,
  rdata,
  wdata,
  flush,
  rd,
  wr,
  stall,

  hit,
  miss

);

  default 
  clocking @(posedge clock);
  endclocking

  default disable iff reset;

  cov_rd_hit: cover property(rd && hit);
  cov_rd_miss: cover property(rd && miss);
  cov_wr_hit: cover property(wr && hit);
  cov_wr_miss: cover property(wr && miss);

endchecker
