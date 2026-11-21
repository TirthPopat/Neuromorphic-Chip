// membrane_mem.v
// Dual-port register file for membrane potentials (1 Read, 1 Write).
// For 16 neurons x 20 bits = 320 registers.

module membrane_mem #(
    parameter MEM_WIDTH = 20,
    parameter NUM_NEURONS = 32,
    parameter ADDR_WIDTH = 5
)(
    input  wire                   clk,
    input  wire                   rst_n,
    
    // Read Port
    input  wire [ADDR_WIDTH-1:0]  rd_addr,
    output reg signed [MEM_WIDTH-1:0] rd_data,
    
    // Write Port
    input  wire                   wr_en,
    input  wire [ADDR_WIDTH-1:0]  wr_addr,
    input  wire signed [MEM_WIDTH-1:0] wr_data
);

    reg signed [MEM_WIDTH-1:0] mem [0:NUM_NEURONS-1];
    integer i;

    always @(posedge clk) begin
        rd_data <= mem[rd_addr];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_NEURONS; i = i + 1)
                mem[i] <= {MEM_WIDTH{1'b0}};
        end else if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end

endmodule
