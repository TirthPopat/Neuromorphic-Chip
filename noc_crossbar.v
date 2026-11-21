// noc_crossbar.v
// Simple broadcast Network-on-Chip (NoC) Arbiter
// Takes packets from 4 cores and broadcasts 1 packet per cycle to all cores.

module noc_crossbar (
    input  wire        clk,
    input  wire        rst_n,

    // Core 0
    input  wire        c0_tx_valid,
    input  wire [6:0]  c0_tx_packet,
    output wire        c0_tx_grant,

    // Core 1
    input  wire        c1_tx_valid,
    input  wire [6:0]  c1_tx_packet,
    output wire        c1_tx_grant,

    // Core 2
    input  wire        c2_tx_valid,
    input  wire [6:0]  c2_tx_packet,
    output wire        c2_tx_grant,

    // Core 3
    input  wire        c3_tx_valid,
    input  wire [6:0]  c3_tx_packet,
    output wire        c3_tx_grant,

    // Broadcast Output (to all NIs)
    output wire        broadcast_valid,
    output wire [6:0]  broadcast_packet
);

    // Simple priority encoder for arbitration (can be upgraded to round-robin later)
    wire [3:0] req = {c3_tx_valid, c2_tx_valid, c1_tx_valid, c0_tx_valid};
    reg  [3:0] grant;

    always @(*) begin
        if      (req[0]) grant = 4'b0001;
        else if (req[1]) grant = 4'b0010;
        else if (req[2]) grant = 4'b0100;
        else if (req[3]) grant = 4'b1000;
        else             grant = 4'b0000;
    end

    assign c0_tx_grant = grant[0];
    assign c1_tx_grant = grant[1];
    assign c2_tx_grant = grant[2];
    assign c3_tx_grant = grant[3];

    assign broadcast_valid = |grant;
    
    assign broadcast_packet = grant[0] ? c0_tx_packet :
                              grant[1] ? c1_tx_packet :
                              grant[2] ? c2_tx_packet :
                              grant[3] ? c3_tx_packet : 7'd0;

endmodule
