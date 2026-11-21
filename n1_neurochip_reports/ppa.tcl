read_liberty /foss/designs/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_liberty /foss/pdks/sky130A/libs.ref/sky130_sram_macros/lib/sky130_sram_2kbyte_1rw1r_32x512_8_TT_1p8V_25C.lib
read_db /foss/designs/OpenROAD-flow-scripts/flow/results/sky130hd/n1_neurochip/base/6_final.odb
read_sdc /foss/designs/OpenROAD-flow-scripts/flow/results/sky130hd/n1_neurochip/base/6_final.sdc
source /foss/designs/OpenROAD-flow-scripts/flow/platforms/sky130hd/setRC.tcl
report_design_area
report_power
report_checks
