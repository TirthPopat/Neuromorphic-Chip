n1_neurochip sky130hd ORFS starter configuration

Copy:
  config.mk
  BUILD
  rules-base.json
  io.tcl
  lif_neuron_array.sdc

into:
  /foss/designs/OpenROAD-flow-scripts/flow/designs/sky130hd/n1_neurochip/

Your RTL files should be in:
  /foss/designs/OpenROAD-flow-scripts/flow/designs/src/n1_neurochip/

The config expects these exact RTL filenames:
  synapse_mac.v
  weight_mem.v
  membrane_accumulator.v
  threshold_detector.v
  reset_leak_unit.v
  lif_neuron_core.v
  lif_neuron_array.v

Run from the ORFS flow directory:
  make DESIGN_CONFIG=./designs/sky130hd/n1_neurochip/config.mk

Note: before running the full flow, fix the two RTL address-width declarations
described in the accompanying ChatGPT response: NEURON_ADDR_W/INPUT_ADDR_W and
ADDR_WIDTH are currently declared as localparams inside the module body but are
used in the ANSI port list.
