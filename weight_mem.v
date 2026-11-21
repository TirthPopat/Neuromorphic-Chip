// weight_mem.v
// Per-neuron synaptic weight store. One write port (shared/muxed at the array
// level), asynchronous flattened read so synapse_mac sees all weights every
// cycle without an extra read latency.

module weight_mem #(
    parameter NUM_INPUTS   = 8,
    parameter WEIGHT_WIDTH = 16,
    parameter ADDR_WIDTH   = (NUM_INPUTS <= 1) ? 1 : $clog2(NUM_INPUTS)
)(
    input  wire                                clk,
    input  wire                                rst_n,
    input  wire                                wr_en,
    input  wire [ADDR_WIDTH-1:0]               wr_addr,
    input  wire signed [WEIGHT_WIDTH-1:0]      wr_data,
    output wire [NUM_INPUTS*WEIGHT_WIDTH-1:0]  weight_flat
);

    reg signed [WEIGHT_WIDTH-1:0] weights [0:NUM_INPUTS-1];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_INPUTS; i = i + 1)
                weights[i] <= {WEIGHT_WIDTH{1'b0}};
        end else if (wr_en) begin
            weights[wr_addr] <= wr_data;
        end
    end

    genvar g;
    generate
        for (g = 0; g < NUM_INPUTS; g = g + 1) begin : PACK
            assign weight_flat[g*WEIGHT_WIDTH +: WEIGHT_WIDTH] = weights[g];
        end
    endgenerate

endmodule
