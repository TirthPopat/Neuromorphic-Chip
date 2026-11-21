`timescale 1ns/1ps

// tb_lif_neuron_array_32x64_macro.v
// Verification testbench for Vector MAC architecture.

module tb_lif_neuron_core;

    localparam NUM_NEURONS   = 32;
    localparam NUM_INPUTS    = 64;
    localparam WEIGHT_WIDTH  = 8;
    localparam MEM_WIDTH     = 20;
    localparam NEURON_ADDR_W = 5;
    localparam CHUNK_ADDR_W  = 4;
    localparam WEIGHT_ADDR_W = 9;

    reg                                 clk = 0;
    reg                                 rst_n = 0;
    reg                                 tick = 0;
    wire                                ready;
    
    reg  [NUM_INPUTS-1:0]               spike_in = 0;
    
    reg                                 wr_en = 0;
    reg  [WEIGHT_ADDR_W-1:0]            wr_addr = 0;
    reg  [31:0]                         wr_data = 0;
    
    reg  signed [MEM_WIDTH-1:0]         threshold = 0;
    reg  signed [MEM_WIDTH-1:0]         leak_rate = 0;
    reg                                 reset_mode = 0;
    
    wire [NUM_NEURONS-1:0]              spike_out;

    lif_neuron_array #(
        .NUM_NEURONS  (NUM_NEURONS),
        .NUM_INPUTS   (NUM_INPUTS),
        .WEIGHT_WIDTH (WEIGHT_WIDTH),
        .MEM_WIDTH    (MEM_WIDTH),
        .NEURON_ADDR_W(NEURON_ADDR_W),
        .CHUNK_ADDR_W (CHUNK_ADDR_W),
        .WEIGHT_ADDR_W(WEIGHT_ADDR_W)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .tick           (tick),
        .ready          (ready),
        .spike_in       (spike_in),
        .wr_en          (wr_en),
        .wr_addr        (wr_addr),
        .wr_data        (wr_data),
        .threshold      (threshold),
        .leak_rate      (leak_rate),
        .reset_mode     (reset_mode),
        .spike_out      (spike_out)
    );

    always #5 clk = ~clk;   // 100 MHz sim clock

    // ---- Helper Tasks ----
    task do_reset;
    begin
        rst_n    = 0;
        tick     = 0;
        spike_in = 0;
        wr_en    = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
    end
    endtask

    task write_weight_chunk;
        input [NEURON_ADDR_W-1:0] n_id;
        input [CHUNK_ADDR_W-1:0]  chunk_id;
        input signed [WEIGHT_WIDTH-1:0] w0;
        input signed [WEIGHT_WIDTH-1:0] w1;
        input signed [WEIGHT_WIDTH-1:0] w2;
        input signed [WEIGHT_WIDTH-1:0] w3;
    begin
        @(posedge clk);
        wr_en = 1;
        wr_addr = {n_id, chunk_id};
        wr_data = {w3, w2, w1, w0};
        @(posedge clk);
        wr_en = 0;
    end
    endtask
    
    reg [NUM_NEURONS-1:0] spikes_caught;

    task eval_timestep;
        input [NUM_INPUTS-1:0] s_in;
    begin
        spikes_caught = 0;
        @(posedge clk);
        spike_in = s_in;
        tick = 1;
        @(posedge clk);
        tick = 0;
        wait(ready == 1'b1);
        @(posedge clk);
    end
    endtask

    // ---- Main test sequence ----
    initial begin
        $dumpfile("tb_lif_neuron_array.vcd");
        $dumpvars(0, tb_lif_neuron_core);

        threshold  = 20'sd100;
        leak_rate  = 20'sd20;
        reset_mode = 1'b1;
        
        do_reset;

        // Load Weights for Neuron 0
        // Chunk 0 (Inputs 0-3): w0=50, w1=10, w2=0, w3=0
        // Chunk 15 (Inputs 60-63): w0=0, w1=0, w2=0, w3=100
        write_weight_chunk(0, 0, 8'sd50, 8'sd10, 8'sd0, 8'sd0);
        write_weight_chunk(0, 15, 8'sd0, 8'sd0, 8'sd0, 8'sd100);
        
        // Load Weights for Neuron 31
        write_weight_chunk(31, 0, 8'sd10, 8'sd20, 8'sd30, 8'sd40);

        $display("Starting Timesteps...");

        // Timestep 1: spike_in[0]=1, spike_in[1]=1, spike_in[63]=1
        // Expected N0 MAC: 50 + 10 + 100 = 160. Mem: 160 - 20 (leak) = 140. FIRE!
        // Expected N31 MAC: 10 + 20 = 30. Mem: 30 - 20 = 10. NO FIRE.
        eval_timestep({1'b1, 61'd0, 1'b1, 1'b1});
        $display("TS 1 done. Spikes caught: %b", spikes_caught);

        if (spikes_caught[0] == 1'b1 && spikes_caught[31] == 1'b0) 
            $display("[PASS] Neurons fired correctly.");
        else 
            $display("[FAIL] Unexpected firing behavior.");

        $finish;
    end
    
    always @(posedge clk) begin
        if (spike_out != 0) begin
            $display("[%0t ns] SPIKE FIRED! Mask: %b", $time, spike_out);
            spikes_caught <= spikes_caught | spike_out;
        end
    end

endmodule
