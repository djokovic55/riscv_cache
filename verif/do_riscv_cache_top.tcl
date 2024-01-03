
clear -all
# verif
analyze -sv09 checker_cache_top.sv bind_top_riscv_system.sv 

# src
analyze -vhdl ../rtl/cache_memory_data_array.vhd ../rtl/main_memory.vhd ../rtl/riscv_cache_controller.vhd ../rtl/Top.vhd 
analyze -vhdl ../rtl/RV32I/control_path/alu_decoder.vhd ../rtl/RV32I/control_path/control_path.vhd ../rtl/RV32I/control_path/ctrl_decoder 

analyze -vhdl ../rtl/RV32I/data_path/ALU_simple.vhd
analyze -vhdl ../rtl/RV32I/data_path/data_path.vhd
analyze -vhdl ../rtl/RV32I/data_path/immediate.vhd
analyze -vhdl ../rtl/RV32I/data_path/register_bank.vhd

analyze -vhdl ../rtl/RV32I/packages/alu_ops_pkg.vhd
analyze -vhdl ../rtl/RV32I/packages/txt_util.vhd

analyze -vhdl ../rtl/RV32I/TOP_RISCV.vhd
analyze -vhdl ../rtl/top_riscv_system.vhd

elaborate -vhdl -top {top_riscv_system} -bbox_a 32768 

clock clock
reset {not reset}
prove -bg -all
