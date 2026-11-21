// threshold_detector.v
// Threshold Detector block — purely combinational comparator.
// Asserts 'fire' when the candidate membrane value meets or exceeds the
// programmable threshold.  The registering of the spike output is handled
// upstream in lif_neuron_core so that the fire decision and the post-fire
// membrane update are computed from the *same* V_candidate in the same
// clock edge — guaranteeing a single-cycle spike pulse.

module threshold_detector #(
    parameter MEM_WIDTH = 20
)(
    input  wire signed [MEM_WIDTH-1:0] v_candidate,
    input  wire signed [MEM_WIDTH-1:0] threshold,
    output wire                        fire
);

    assign fire = (v_candidate >= threshold);

endmodule
