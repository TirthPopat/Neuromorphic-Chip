# OpenROAD-flow-scripts configuration
# Design: n1_neurochip
# Target platform: sky130hd
#
# RTL is kept in:
#   flow/designs/src/n1_neurochip/
#
# Run from:
#   cd /foss/designs/OpenROAD-flow-scripts/flow
#   make DESIGN_CONFIG=./designs/sky130hd/n1_neurochip/config.mk

export DESIGN_NAME     = multicore_tile
export DESIGN_NICKNAME = n1_neurochip
export PLATFORM        = sky130hd

# All synthesizable RTL sources for the top-level lif_neuron_array.
export VERILOG_FILES = \
  $(DESIGN_HOME)/src/$(DESIGN_NICKNAME)/synapse_mac.v \
  $(DESIGN_HOME)/src/$(DESIGN_NICKNAME)/weight_sram.v \
  $(DESIGN_HOME)/src/$(DESIGN_NICKNAME)/membrane_mem.v \
  $(DESIGN_HOME)/src/$(DESIGN_NICKNAME)/tm_controller.v \
    $(DESIGN_HOME)/src/$(DESIGN_NICKNAME)/stdp_engine.v \
  $(DESIGN_HOME)/src/$(DESIGN_NICKNAME)/membrane_accumulator.v \
  $(DESIGN_HOME)/src/$(DESIGN_NICKNAME)/threshold_detector.v \
  $(DESIGN_HOME)/src/$(DESIGN_NICKNAME)/reset_leak_unit.v \
  $(DESIGN_HOME)/src/$(DESIGN_NICKNAME)/lif_neuron_core.v \
  $(DESIGN_HOME)/src/$(DESIGN_NICKNAME)/lif_neuron_array.v \
  $(DESIGN_HOME)/src/$(DESIGN_NICKNAME)/network_interface.v \
  $(DESIGN_HOME)/src/$(DESIGN_NICKNAME)/noc_crossbar.v \
  $(DESIGN_HOME)/src/$(DESIGN_NICKNAME)/multicore_tile.v

# Timing constraints.
export SDC_FILE = $(DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NICKNAME)/multicore_tile.sdc

# Manual I/O-side constraints.
export IO_CONSTRAINTS = $(DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NICKNAME)/io.tcl

# Conservative first-pass settings for a small/medium RTL block.
# Tune these after the first floorplan/place/route run.
export CORE_UTILIZATION = 5
export PLACE_DENSITY    = 0.15

# Initial timing target is defined by multicore_tile.sdc (10 ns = 100 MHz).
export TNS_END_PERCENT = 100


# Sky130 routing range.
export MIN_ROUTING_LAYER = met1
export MAX_ROUTING_LAYER = met5
export SYNTH_MEMORY_MAX_BITS = 131072
export ADDITIONAL_LEFS = /foss/pdks/sky130A/libs.ref/sky130_sram_macros/lef/sky130_sram_2kbyte_1rw1r_32x512_8.lef
export ADDITIONAL_LIBS = /foss/pdks/sky130A/libs.ref/sky130_sram_macros/lib/sky130_sram_2kbyte_1rw1r_32x512_8_TT_1p8V_25C.lib
export ADDITIONAL_GDS = /foss/pdks/sky130A/libs.ref/sky130_sram_macros/gds/sky130_sram_2kbyte_1rw1r_32x512_8.gds
export MACRO_PLACE_HALO = 50 50
export MACRO_PLACE_CHANNEL = 80 80
export PDN_TCL = $(DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NICKNAME)/pdn.tcl
export MACRO_PLACEMENT = $(DESIGN_DIR)/macro_placement.cfg
