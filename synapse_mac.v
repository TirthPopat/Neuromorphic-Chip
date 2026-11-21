// synapse_mac.v
// 4-Input Vector MAC for 32-bit SRAM Data Packing

module synapse_mac #(
    parameter WEIGHT_WIDTH = 8,
    parameter ACC_WIDTH    = 20
)(
    input  wire                             clk,
    input  wire                             rst_n,

    input  wire                             mac_valid,  // High when weight and spike_bit are valid
    input  wire                             mac_clear,  // High on first chunk to restart accumulation
    input  wire [3:0]                       spike_bits, // 4 Spikes
    input  wire [31:0]                      weight_vec, // 4 Weights (packed)

    output reg  signed [ACC_WIDTH-1:0]      synaptic_current // the accumulator register
);

    wire signed [WEIGHT_WIDTH-1:0] w0 = weight_vec[7:0];
    wire signed [WEIGHT_WIDTH-1:0] w1 = weight_vec[15:8];
    wire signed [WEIGHT_WIDTH-1:0] w2 = weight_vec[23:16];
    wire signed [WEIGHT_WIDTH-1:0] w3 = weight_vec[31:24];

    wire signed [ACC_WIDTH-1:0] val0 = spike_bits[0] ? $signed(w0) : {ACC_WIDTH{1'b0}};
    wire signed [ACC_WIDTH-1:0] val1 = spike_bits[1] ? $signed(w1) : {ACC_WIDTH{1'b0}};
    wire signed [ACC_WIDTH-1:0] val2 = spike_bits[2] ? $signed(w2) : {ACC_WIDTH{1'b0}};
    wire signed [ACC_WIDTH-1:0] val3 = spike_bits[3] ? $signed(w3) : {ACC_WIDTH{1'b0}};

    wire signed [ACC_WIDTH-1:0] sum = val0 + val1 + val2 + val3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            synaptic_current <= {ACC_WIDTH{1'b0}};
        end else if (mac_valid) begin
            if (mac_clear) begin
                synaptic_current <= sum; // Overwrite on first chunk
            end else begin
                synaptic_current <= synaptic_current + sum; // Accumulate
            end
        end
    end

endmodule
