// network_interface.v
// Network Interface for converting parallel core spikes to/from NoC AER packets

module network_interface #(
    parameter CORE_ID    = 2'b00,
    parameter NUM_NEURONS = 32,
    parameter NUM_INPUTS  = 64
)(
    input  wire                 clk,
    input  wire                 rst_n,

    // Core Interface (Spike RX)
    input  wire                 tick,
    output wire [63:0]          core_spike_in,
    
    // Core Interface (Spike TX)
    input  wire                 core_spike_out_valid,
    input  wire [4:0]           core_spike_out_addr,

    // NoC Interface (Spike RX)
    input  wire                 noc_rx_valid,
    input  wire [6:0]           noc_rx_packet, // [6:5] Src Core, [4:0] Src Neuron

    // NoC Interface (Spike TX)
    output wire                 noc_tx_valid,
    output wire [6:0]           noc_tx_packet, // [6:5] My Core, [4:0] My Neuron
    input  wire                 noc_tx_grant,  // High when NoC accepts the packet

    // Host Programming Interface (for Inbound Routing Table)
    input  wire                 host_wr_en,
    input  wire [6:0]           host_wr_addr,
    input  wire [6:0]           host_wr_data  // [6] Valid, [5:0] Local Synapse ID
);

    // ==========================================
    // 1. INBOUND: NoC to Core (Routing Table)
    // ==========================================
    // 128-entry Routing Table: Maps incoming 7-bit global packet to a 6-bit local synapse ID
    // Format: {Valid (1), Local_Synapse_ID (6)}
    reg [6:0] inbound_rt [0:127];
    
    integer i;
    initial begin
        for (i = 0; i < 128; i = i + 1) inbound_rt[i] = 0;
    end

    always @(posedge clk) begin
        if (host_wr_en) begin
            inbound_rt[host_wr_addr] <= host_wr_data;
        end
    end

    // Pipeline NoC RX to SRAM read
    reg        rx_valid_q;
    reg [6:0]  rx_lookup_res;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_valid_q <= 0;
            rx_lookup_res <= 0;
        end else begin
            rx_valid_q <= noc_rx_valid;
            if (noc_rx_valid) begin
                rx_lookup_res <= inbound_rt[noc_rx_packet];
                $display("Time: %0t | Core %d received packet -> SrcCore: %d, SrcNeuron: %d. Looking up...", 
                    $time, CORE_ID, noc_rx_packet[6:5], noc_rx_packet[4:0]);
            end
        end
    end

    // Buffer to accumulate input spikes for the next tick
    reg [63:0] spike_buffer;
    reg [63:0] spike_in_latch;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spike_buffer   <= 64'd0;
            spike_in_latch <= 64'd0;
        end else begin
            if (tick) begin
                spike_in_latch <= spike_buffer;
                spike_buffer   <= 64'd0; // Clear accumulation buffer
            end else if (rx_valid_q && rx_lookup_res[6]) begin
                spike_buffer[rx_lookup_res[5:0]] <= 1'b1; // Set corresponding synapse bit
            end
        end
    end

    assign core_spike_in = spike_in_latch;

    // ==========================================
    // 2. OUTBOUND: Core to NoC (TX FIFO)
    // ==========================================
    // 32-entry FIFO to buffer outgoing spikes since NoC might be busy
    reg [4:0] tx_fifo [0:31];
    reg [4:0] tx_wr_ptr;
    reg [4:0] tx_rd_ptr;
    reg [5:0] tx_count; // 0 to 32

    wire fifo_empty = (tx_count == 0);
    wire fifo_full  = (tx_count == 32);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_wr_ptr <= 0;
            tx_rd_ptr <= 0;
            tx_count  <= 0;
        end else begin
            // Write
            if (core_spike_out_valid && !fifo_full) begin
                tx_fifo[tx_wr_ptr] <= core_spike_out_addr;
            end
            
            // Read
            if (!fifo_empty && noc_tx_grant) begin
                tx_rd_ptr <= tx_rd_ptr + 1;
            end
            
            // Pointers
            if (core_spike_out_valid && !fifo_full) begin
                tx_wr_ptr <= tx_wr_ptr + 1;
            end
            
            // Count
            if ((core_spike_out_valid && !fifo_full) && (!(!fifo_empty && noc_tx_grant)))
                tx_count <= tx_count + 1;
            else if (!(core_spike_out_valid && !fifo_full) && (!fifo_empty && noc_tx_grant))
                tx_count <= tx_count - 1;
        end
    end

    assign noc_tx_valid  = !fifo_empty;
    assign noc_tx_packet = {CORE_ID, tx_fifo[tx_rd_ptr]};

    always @(posedge clk) begin
        if (noc_tx_valid && noc_tx_grant) begin
            $display("Time: %0t | Core %d emitting packet -> SrcCore: %d, SrcNeuron: %d", 
                $time, CORE_ID, noc_tx_packet[6:5], noc_tx_packet[4:0]);
        end
    end

endmodule
