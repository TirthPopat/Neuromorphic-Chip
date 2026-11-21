// weight_sram.v
// Wrapper for 32x512 SRAM

module weight_sram (
    input  wire                   clk,
    
    // Port 0: RW (Host interface)
    input  wire                   csb0,   // active low chip select
    input  wire                   web0,   // active low write enable
    input  wire [8:0]             addr0,
    input  wire [31:0]            din0,
    
    // Port 1: R (Datapath interface)
    input  wire                   csb1,   // active low chip select
    input  wire [8:0]             addr1,
    output wire [31:0]            dout1
);

`ifdef SYNTHESIS
    // Hard Macro Instance for OpenROAD
    sky130_sram_2kbyte_1rw1r_32x512_8 u_hard_macro (
`ifdef USE_POWER_PINS
        .vccd1 (1'b1),
        .vssd1 (1'b0),
`endif
        .clk0   (clk),
        .csb0   (csb0),
        .web0   (web0),
        .wmask0 (4'b1111), // write all 4 bytes
        .addr0  (addr0),
        .din0   (din0),
        .dout0  (), // unconnected
        
        .clk1   (clk),
        .csb1   (csb1),
        .addr1  (addr1),
        .dout1  (dout1)
    );
`else
    // Behavioral Model for iverilog
    reg [31:0] mem [0:511];
    
    // Initialize to zero
    integer i;
    initial begin
        for (i = 0; i < 512; i = i + 1)
            mem[i] = 32'd0;
    end

    // Port 0: Write only
    always @(posedge clk) begin
        if (!csb0 && !web0) begin
            mem[addr0] <= din0;
        end
    end

    // Port 1: Read only (Synchronous Read)
    reg [31:0] dout1_reg;
    always @(posedge clk) begin
        if (!csb1) begin
            dout1_reg <= mem[addr1];
        end
    end
    assign dout1 = dout1_reg;
`endif

endmodule
