// lif_neuron_core.v
// Datapath for Vector MAC architecture.

module lif_neuron_core #(
    parameter WEIGHT_WIDTH = 8,
    parameter MEM_WIDTH    = 20
)(
    input  wire                                clk,
    input  wire                                rst_n,

    // MAC control
    input  wire                                mac_valid,
    input  wire                                mac_clear,
    input  wire [3:0]                          spike_bits,
    input  wire [31:0]                         weight_vec,

    // Membrane control
    input  wire signed [MEM_WIDTH-1:0]         membrane_in,
    input  wire signed [MEM_WIDTH-1:0]         threshold,
    input  wire signed [MEM_WIDTH-1:0]         leak_rate,
    input  wire                                reset_mode,

    output wire                                fire,
    output wire signed [MEM_WIDTH-1:0]         next_membrane
);

    wire signed [MEM_WIDTH-1:0] synaptic_current;
    wire signed [MEM_WIDTH-1:0] v_candidate;
    wire signed [MEM_WIDTH-1:0] reset_value;

    // --- Vector MAC Pipeline (Cycle 1) ---
    synapse_mac #(
        .WEIGHT_WIDTH (WEIGHT_WIDTH),
        .ACC_WIDTH    (MEM_WIDTH)
    ) u_synapse_mac (
        .clk              (clk),
        .rst_n            (rst_n),
        .mac_valid        (mac_valid),
        .mac_clear        (mac_clear),
        .spike_bits       (spike_bits),
        .weight_vec       (weight_vec),
        .synaptic_current (synaptic_current)
    );

    // --- Membrane Combinational Logic (Cycle 2) ---
    membrane_accumulator #(
        .MEM_WIDTH (MEM_WIDTH)
    ) u_membrane_accumulator (
        .membrane_in        (membrane_in),
        .synaptic_current   (synaptic_current),
        .leak_rate          (leak_rate),
        .v_candidate        (v_candidate)
    );

    threshold_detector #(
        .MEM_WIDTH (MEM_WIDTH)
    ) u_threshold_detector (
        .v_candidate (v_candidate),
        .threshold   (threshold),
        .fire        (fire)
    );

    reset_leak_unit #(
        .MEM_WIDTH (MEM_WIDTH)
    ) u_reset_leak_unit (
        .fire        (fire),
        .v_candidate (v_candidate),
        .threshold   (threshold),
        .reset_mode  (reset_mode),
        .reset_value (reset_value)
    );
    
    assign next_membrane = fire ? reset_value : v_candidate;

endmodule
