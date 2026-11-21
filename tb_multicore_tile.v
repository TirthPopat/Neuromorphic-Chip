// tb_multicore_tile.v
// Testbench to verify NoC routing and Multicast

`timescale 1ns/1ps

module tb_multicore_tile;

    reg clk;
    reg rst_n;
    reg tick;
    wire [3:0] ready_cores;
    
    reg host_wr_en;
    reg [11:0] host_wr_addr;
    reg [31:0] host_wr_data;
    
    reg signed [19:0] threshold;
    reg signed [19:0] leak_rate;
    reg reset_mode;

    multicore_tile #(
        .MEM_WIDTH(20)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tick(tick),
        .ready_cores(ready_cores),
        .host_wr_en(host_wr_en),
        .host_wr_addr(host_wr_addr),
        .host_wr_data(host_wr_data),
        .threshold(threshold),
        .leak_rate(leak_rate),
        .reset_mode(reset_mode)
    );

    always #5 clk = ~clk;

    // Helper task to program NI routing table
    task program_route;
        input [1:0] target_core;
        input [1:0] src_core;
        input [4:0] src_neuron;
        input [5:0] local_synapse;
        begin
            host_wr_en = 1;
            // Addr = [11:10] Core, [9] = 1 (NI), [8:7] = 0, [6:0] = {src_core, src_neuron}
            host_wr_addr = {target_core, 1'b1, 2'b00, src_core, src_neuron};
            // Data = [6] Valid=1, [5:0] local synapse
            host_wr_data = {25'd0, 1'b1, local_synapse};
            @(posedge clk);
            host_wr_en = 0;
            @(posedge clk);
        end
    endtask

    // Helper task to program SRAM weights
    task program_weight;
        input [1:0] target_core;
        input [4:0] neuron;
        input [3:0] chunk;
        input [31:0] weight_vec;
        begin
            host_wr_en = 1;
            // Addr = [11:10] Core, [9] = 0 (SRAM), [8:0] = {neuron, chunk}
            host_wr_addr = {target_core, 1'b0, neuron, chunk};
            host_wr_data = weight_vec;
            @(posedge clk);
            host_wr_en = 0;
            @(posedge clk);
        end
    endtask

    initial begin
        // Initialize
        $dumpfile("tb_multicore_tile.vcd");
        $dumpvars(0, tb_multicore_tile);
        
        clk = 0;
        rst_n = 0;
        tick = 0;
        host_wr_en = 0;
        host_wr_addr = 0;
        host_wr_data = 0;
        threshold = 20'd100;
        leak_rate = 20'd0;
        reset_mode = 0;

        #20 rst_n = 1;
        @(posedge clk);

        // ---------------------------------------------------------
        // 1. Program Routing Tables (Multicast)
        // We want Core 0, Neuron 5 to fire.
        // Its spike should route to Core 1 (Synapse 12) AND Core 2 (Synapse 40)
        // ---------------------------------------------------------
        $display("Programming Routing Tables...");
        // Target=Core1, Src=Core0,Neuron5, LocalSyn=12
        program_route(2'd1, 2'd0, 5'd5, 6'd12);
        
        // Target=Core2, Src=Core0,Neuron5, LocalSyn=40
        program_route(2'd2, 2'd0, 5'd5, 6'd40);

        // ---------------------------------------------------------
        // 2. Program Weights to force Core 0 Neuron 5 to fire
        // ---------------------------------------------------------
        // We can force a fire by just giving it a massive bias or giving it a spike.
        // Actually, since there are no external spikes yet, let's just make the weight of
        // synapse 0 very high, and artificially inject a spike into Core 0's buffer?
        // OR better: we can use leak_rate = -120 to artificially increase membrane!
        // No, leak_rate is global.
        // Let's just manually write to Core 0's network interface spike buffer using a backdoor,
        // or just add a massive weight to chunk 0 and force spike_in[0]=1.
        // Wait, how do we get a spike into Core 0 to start the chain?
        // Let's route a dummy packet to Core 0!
        // We can simulate the NoC receiving a packet from an "external" source? No, NoC is closed.
        // Let's program Core 0's routing table so that Core 3 Neuron 0 -> Core 0 Synapse 0.
        // But how does Core 3 Neuron 0 fire?
        // Ah, what if we just set the membrane potential of Core 0 Neuron 5 directly?
        // Or we can just set a weight so high that even with 0 inputs it fires? No, MAC multiplies by 0.
        // Let's just force `dut.u_ni_0.spike_buffer[0] = 1;`
        $display("Injecting initial spike into Core 0...");
        @(posedge clk);
        dut.u_ni_0.spike_buffer[0] = 1'b1;
        
        // Program Core 0, Neuron 5, Chunk 0 to have weight=120 on synapse 0
        // Weight vec = {w3, w2, w1, w0} -> {0, 0, 0, 120} = 0x00000078
        program_weight(2'd0, 5'd5, 4'd0, 32'h00000078);

        // ---------------------------------------------------------
        // 3. Tick 1: Core 0 evaluates and fires
        // ---------------------------------------------------------
        $display("Tick 1: Core 0 should fire Neuron 5...");
        tick = 1; @(posedge clk); tick = 0;
        
        wait (ready_cores == 4'b1111);
        @(posedge clk);
        
        // At the end of Tick 1, Core 0 should have emitted packet [Core0, N5].
        // The NoC should have broadcasted it.
        // Core 1 and Core 2 NIs should have received it and set their spike buffers.
        $display("Core 1 Spike Buffer: %b", dut.u_ni_1.spike_buffer);
        $display("Core 2 Spike Buffer: %b", dut.u_ni_2.spike_buffer);

        if (dut.u_ni_1.spike_buffer[12] == 1'b1 && dut.u_ni_2.spike_buffer[40] == 1'b1) begin
            $display("SUCCESS: Multicast packet successfully routed to Core 1 and Core 2!");
        end else begin
            $display("ERROR: Multicast routing failed.");
        end

        // ---------------------------------------------------------
        // 4. Tick 2: Core 1 and Core 2 process the received spikes
        // ---------------------------------------------------------
        $display("Tick 2: Cores process received spikes...");
        tick = 1; @(posedge clk); tick = 0;
        
        wait (ready_cores == 4'b1111);
        @(posedge clk);

        $display("Simulation complete.");
        $finish;
    end

endmodule
