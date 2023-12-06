
clear -all
# verif
analyze -sv09 checker_cache_top.sv bind_cache_top.sv 

# src
analyze -vhdl cache_memory_data_array.vhd main_memory.vhd riscv_cache_controller.vhd top.vhd 

elaborate -vhdl -top {top}

clock clock
reset reset
prove -bg -all