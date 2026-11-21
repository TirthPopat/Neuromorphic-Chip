// reset_leak_unit.v
// Reset block — purely combinational.
// Computes the post-fire membrane value from the *candidate* potential
// (the same value that the threshold detector uses to decide 'fire').
//
//   reset_mode = 0 → hard reset: membrane goes to 0 on fire
//   reset_mode = 1 → subtractive reset: membrane = V_candidate − threshold
//                     (preserves supra-threshold overshoot for more
//                      accurate spike timing)
//
// When the neuron does NOT fire, reset_value is unused — lif_neuron_core
// selects v_candidate directly in that case.

module reset_leak_unit #(
    parameter MEM_WIDTH = 20
)(
    input  wire                        fire,
    input  wire signed [MEM_WIDTH-1:0] v_candidate,
    input  wire signed [MEM_WIDTH-1:0] threshold,
    input  wire                        reset_mode,   // 0 = hard reset to 0, 1 = subtractive reset
    output wire signed [MEM_WIDTH-1:0] reset_value
);

    assign reset_value = reset_mode ? (v_candidate - threshold) : {MEM_WIDTH{1'b0}};

endmodule
