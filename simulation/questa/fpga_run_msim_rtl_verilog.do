transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog  -work work +incdir+/home/loki0b/eecs/projects/control-unit {/home/loki0b/eecs/projects/control-unit/memory.v}
vlog  -work work +incdir+/home/loki0b/eecs/projects/control-unit {/home/loki0b/eecs/projects/control-unit/lcd_controller.v}
vlog  -work work +incdir+/home/loki0b/eecs/projects/control-unit {/home/loki0b/eecs/projects/control-unit/fpga.v}
vlog  -work work +incdir+/home/loki0b/eecs/projects/control-unit {/home/loki0b/eecs/projects/control-unit/cpu.v}
vlog  -work work +incdir+/home/loki0b/eecs/projects/control-unit {/home/loki0b/eecs/projects/control-unit/control_unit.v}
vlog  -work work +incdir+/home/loki0b/eecs/projects/control-unit {/home/loki0b/eecs/projects/control-unit/button_handler.v}
vlog  -work work +incdir+/home/loki0b/eecs/projects/control-unit {/home/loki0b/eecs/projects/control-unit/arithmetic_logic_unit.v}

vlog  -work work +incdir+/home/loki0b/eecs/projects/control-unit {/home/loki0b/eecs/projects/control-unit/fpga_tb.v}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L rtl_work -L work -voptargs="+acc"  fpga_tb

add wave *
view structure
view signals
run -all
