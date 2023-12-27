
checker checker_cache_top(
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
  miss,
  cache_state

);

  default 
  clocking @(posedge clock);
  endclocking

  default disable iff !reset;
  parameter [2:0] idle = 3'h0;
  parameter [2:0] compare_tag = 3'h1;
  parameter [2:0] write_back = 3'h2;
  parameter [2:0] allocate_refil = 3'h3;
  parameter [2:0] allocate_update = 3'h4;


  asm_no_rd_and_wr: assume property(not(rd && wr));
  asm_no_zero_tag: assume property(addr[9:4] != '0);
  asm_data: assume property(wdata inside {32'hA, 32'hB, 32'hC, 32'hD, 32'hE, 32'hF});
  asm_addr_stability: assume property(cache_state != idle |-> $stable(addr));


  cov_rd_inst: cover property(rd);
  cov_wr_inst: cover property(wr);

  cov_rd_hit: cover property(rd && hit);
  cov_rd_miss: cover property(rd && miss);
  cov_wr_hit: cover property(wr && hit);
  cov_wr_miss: cover property(wr && miss);

  cov_rd_miss_wb_allocate: cover property((rd && cache_state == write_back) ##[1:3] cache_state == allocate_refil); 

endchecker

