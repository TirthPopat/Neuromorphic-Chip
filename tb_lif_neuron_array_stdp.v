`timescale 1ns/1ps

module tb_lif_neuron_array_stdp;
    parameter NUM_NEURONS  = 32;
    parameter NUM_INPUTS   = 64;
    parameter WEIGHT_WIDTH = 8;
    parameter MEM_WIDTH    = 20;

    reg clk, rst_n, tick;
    wire ready;
    reg [NUM_INPUTS-1:0] spike_in;
    reg wr_en;
    reg [8:0] wr_addr;
    reg [31:0] wr_data;
    reg signed [MEM_WIDTH-1:0] threshold, leak_rate;
    reg reset_mode;
    wire [NUM_NEURONS-1:0] spike_out;

    lif_neuron_array #(
        .NUM_INPUTS(NUM_INPUTS),
        .NUM_CHUNKS(16),
        .WEIGHT_WIDTH(WEIGHT_WIDTH),
        .MEM_WIDTH(MEM_WIDTH)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .tick(tick), .ready(ready),
        .spike_in(spike_in),
        .wr_en(wr_en), .wr_addr(wr_addr), .wr_data(wr_data),
        .threshold(threshold), .leak_rate(leak_rate), .reset_mode(reset_mode),
        .spike_out(spike_out)
    );

    always #5 clk = ~clk;

    reg [NUM_NEURONS-1:0] captured_spikes;
    always @(posedge clk) begin
        if (!rst_n) captured_spikes <= 0;
        else if (tick) captured_spikes <= 0;
        else if (|spike_out) captured_spikes <= captured_spikes | spike_out;
    end
    
    always @(posedge clk) begin
        if (dut.mac_valid && dut.u_controller.pipe_neuron_c2 == 0) begin
            $display("Neuron 0 Chunk %d MAC Eval - spike:%b | w_vec:%h | sum:%d | syn_cur:%d | clear:%b", 
                dut.u_controller.pipe_chunk_c2, dut.u_datapath.spike_bits, dut.u_datapath.weight_vec, 
                dut.u_datapath.u_synapse_mac.sum, dut.u_datapath.synaptic_current, dut.mac_clear);
        end
        if (dut.mem_write_en && dut.mem_wr_addr == 0) begin
            $display("Neuron 0 Membrane Written: next=%d | mem_in=%d | syn_cur=%d | cand=%d | leak=%d | reset=%d | fire=%b", 
                dut.next_membrane, dut.membrane_in, dut.u_datapath.synaptic_current, 
                dut.u_datapath.v_candidate, dut.u_datapath.u_membrane_accumulator.leaked, 
                dut.u_datapath.reset_value, dut.fire);
        end
    end

    integer i;
    initial begin
        $dumpfile("tb_lif_neuron_array_stdp.vcd");
        $dumpvars(0, tb_lif_neuron_array_stdp);

        for (i = 0; i < NUM_NEURONS; i = i + 1)
            dut.u_membrane_mem.mem[i] = 0;

        clk = 0; rst_n = 0; tick = 0;
        spike_in = 0; wr_en = 0; wr_addr = 0; wr_data = 0;
        threshold = 20'd0; leak_rate = 20'd0; reset_mode = 0;
        
        #15 rst_n = 1;
        #10;
        
        // Initialize Weights for Neuron 0 to 0
        wr_en = 1;
        wr_addr = 0; wr_data = 32'h00000000; #10; // Chunk 0
        wr_en = 0;
        #10;
        
        $display("--- STDP Test ---");
        
        // Tick 1: Provide spike_in[0] = 1, but weights are 0, so no fire.
        spike_in = 64'h1;
        tick = 1; @(posedge clk) tick = 0;
        wait(ready); @(posedge clk);
        $display("Tick 1 Spike Out: %b", captured_spikes);
        
        // Host overrides weights to force a fire in next tick
        // Set weights for Neuron 0 to large values so it fires.
        @(posedge clk);
        wr_en = 1;
        wr_addr = 0; wr_data = 32'h70707070; @(posedge clk); 
        wr_addr = 1; wr_data = 32'h70707070; @(posedge clk); 
        wr_en = 0;
        @(posedge clk);
        $display("After Host Write - Chunk 0: %h", dut.u_weight_sram.mem[0]);
        
        // Tick 2: Force fire. spike_in[0] = 1 (LTP for weight 0), spike_in[4] = 1 (LTP for weight 4).
        spike_in = 64'h0000000000000011; // bit 0 and bit 4
        tick = 1; @(posedge clk) tick = 0;
        wait(ready); @(posedge clk);
        $display("Tick 2 Spike Out: %b (Expected to fire)", captured_spikes);
        
        $display("Tick 3: Reading learned weights back via host interface");
        wr_en = 0;
        wr_addr = 0; 
        @(posedge clk); @(posedge clk);
        $display("Learned Weights Chunk 0: %h", dut.u_weight_sram.mem[0]);
        $display("Learned Weights Chunk 1: %h", dut.u_weight_sram.mem[1]);
        
        $display("Simulation complete.");
        $finish;
    end
endmodule
