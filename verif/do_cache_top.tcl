
clear -all
# verif
analyze -sv09 checker_cache_top.sv bind_cache_top.sv 

# src
analyze -vhdl ../rtl/cache_memory_data_array.vhd ../rtl/main_memory.vhd ../rtl/riscv_cache_controller.vhd ../rtl/Top.vhd 

elaborate -vhdl -top {Top} -bbox_a 32768 

clock clock
reset {not reset}
prove -bg -all
