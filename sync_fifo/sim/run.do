# ModelSim script. Run from this folder with:  vsim -do run.do
# Change TB to the name of your testbench module if it is different.
set TB tb_sync_fifo

vlib work
vmap work work
vlog -work work ../rtl/*.v
vlog -work work ../tb/*.v
vsim -voptargs=+acc work.$TB
add wave -r /*
run -all
