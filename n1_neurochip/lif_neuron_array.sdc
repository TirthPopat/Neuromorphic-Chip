# lif_neuron_array.sdc
# Timing constraints for the LIF neuromorphic tile.
# Adjust clk_period after your first STA run — do NOT assume a target Fmax
# until OpenROAD actually reports timing closure.

current_design lif_neuron_array

set clk_name   clk
set clk_port   clk
set clk_period 10.0    ;# ns -> 100 MHz initial target

create_clock -name $clk_name -period $clk_period [get_ports $clk_port]
set_clock_uncertainty 0.25 [get_clocks $clk_name]

set_input_delay  [expr {$clk_period * 0.3}] -clock $clk_name [all_inputs]
set_output_delay [expr {$clk_period * 0.3}] -clock $clk_name [all_outputs]

# Use a generic input transition rather than guessing a library cell.
# Replace with a specific PDK driving cell (e.g. sky130_fd_sc_hd__buf_2)
# once the target library is confirmed and available.
set_input_transition 0.15 [all_inputs]
set_load 0.05 [all_outputs]
