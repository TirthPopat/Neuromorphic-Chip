// multicore_tile.v
// Top-level 4-Core Tile with NoC and Global Host Interface

module multicore_tile #(
    parameter MEM_WIDTH = 20
)(
    input  wire                 clk,
    input  wire                 rst_n,

    // Global Time-multiplexed control
    input  wire                 tick,
    output wire [3:0]           ready_cores,

    // Global Host Programming Interface
    // Addr [11:10] = Core ID (0, 1, 2, 3)
    // Addr [9]     = Target (0: SRAM Weights, 1: NI Routing Table)
    // Addr [8:0]   = Word Address
    input  wire                 host_wr_en,
    input  wire [11:0]          host_wr_addr,
    input  wire [31:0]          host_wr_data,

    // Global Parameters
    input  wire signed [MEM_WIDTH-1:0] threshold,
    input  wire signed [MEM_WIDTH-1:0] leak_rate,
    input  wire                        reset_mode
);

    // ==========================================
    // NoC Wires
    // ==========================================
    wire        c0_tx_valid, c1_tx_valid, c2_tx_valid, c3_tx_valid;
    wire [6:0]  c0_tx_packet, c1_tx_packet, c2_tx_packet, c3_tx_packet;
    wire        c0_tx_grant, c1_tx_grant, c2_tx_grant, c3_tx_grant;
    
    wire        broadcast_valid;
    wire [6:0]  broadcast_packet;

    // ==========================================
    // Host Decode Logic
    // ==========================================
    wire [3:0] core_sel = (host_wr_addr[11:10] == 2'b00) ? 4'b0001 :
                          (host_wr_addr[11:10] == 2'b01) ? 4'b0010 :
                          (host_wr_addr[11:10] == 2'b10) ? 4'b0100 :
                          (host_wr_addr[11:10] == 2'b11) ? 4'b1000 : 4'b0000;

    wire target_is_ni   = host_wr_addr[9];
    wire target_is_sram = ~host_wr_addr[9];

    // Core 0 Host
    wire c0_sram_wr_en = host_wr_en & core_sel[0] & target_is_sram;
    wire c0_ni_wr_en   = host_wr_en & core_sel[0] & target_is_ni;
    // Core 1 Host
    wire c1_sram_wr_en = host_wr_en & core_sel[1] & target_is_sram;
    wire c1_ni_wr_en   = host_wr_en & core_sel[1] & target_is_ni;
    // Core 2 Host
    wire c2_sram_wr_en = host_wr_en & core_sel[2] & target_is_sram;
    wire c2_ni_wr_en   = host_wr_en & core_sel[2] & target_is_ni;
    // Core 3 Host
    wire c3_sram_wr_en = host_wr_en & core_sel[3] & target_is_sram;
    wire c3_ni_wr_en   = host_wr_en & core_sel[3] & target_is_ni;

    // Common Address
    wire [8:0] sram_wr_addr = host_wr_addr[8:0];
    wire [6:0] ni_wr_addr   = host_wr_addr[6:0];
    wire [6:0] ni_wr_data   = host_wr_data[6:0]; // [6] Valid, [5:0] Synapse ID

    // ==========================================
    // NoC Arbiter
    // ==========================================
    noc_crossbar u_noc (
        .clk              (clk),
        .rst_n            (rst_n),
        .c0_tx_valid      (c0_tx_valid),
        .c0_tx_packet     (c0_tx_packet),
        .c0_tx_grant      (c0_tx_grant),
        .c1_tx_valid      (c1_tx_valid),
        .c1_tx_packet     (c1_tx_packet),
        .c1_tx_grant      (c1_tx_grant),
        .c2_tx_valid      (c2_tx_valid),
        .c2_tx_packet     (c2_tx_packet),
        .c2_tx_grant      (c2_tx_grant),
        .c3_tx_valid      (c3_tx_valid),
        .c3_tx_packet     (c3_tx_packet),
        .c3_tx_grant      (c3_tx_grant),
        .broadcast_valid  (broadcast_valid),
        .broadcast_packet (broadcast_packet)
    );

    // ==========================================
    // CORE 0
    // ==========================================
    wire [63:0] c0_spike_in;
    wire        c0_aer_tx_valid;
    wire [4:0]  c0_aer_tx_addr;

    network_interface #(.CORE_ID(2'd0)) u_ni_0 (
        .clk                  (clk),
        .rst_n                (rst_n),
        .tick                 (tick),
        .core_spike_in        (c0_spike_in),
        .core_spike_out_valid (c0_aer_tx_valid),
        .core_spike_out_addr  (c0_aer_tx_addr),
        .noc_rx_valid         (broadcast_valid),
        .noc_rx_packet        (broadcast_packet),
        .noc_tx_valid         (c0_tx_valid),
        .noc_tx_packet        (c0_tx_packet),
        .noc_tx_grant         (c0_tx_grant),
        .host_wr_en           (c0_ni_wr_en),
        .host_wr_addr         (ni_wr_addr),
        .host_wr_data         (ni_wr_data)
    );

    lif_neuron_array u_core_0 (
        .clk             (clk),
        .rst_n           (rst_n),
        .tick            (tick),
        .ready           (ready_cores[0]),
        .spike_in        (c0_spike_in),
        .wr_en           (c0_sram_wr_en),
        .wr_addr         (sram_wr_addr),
        .wr_data         (host_wr_data),
        .threshold       (threshold),
        .leak_rate       (leak_rate),
        .reset_mode      (reset_mode),
        .aer_tx_valid    (c0_aer_tx_valid),
        .aer_tx_addr     (c0_aer_tx_addr)
    );

    // ==========================================
    // CORE 1
    // ==========================================
    wire [63:0] c1_spike_in;
    wire        c1_aer_tx_valid;
    wire [4:0]  c1_aer_tx_addr;

    network_interface #(.CORE_ID(2'd1)) u_ni_1 (
        .clk                  (clk),
        .rst_n                (rst_n),
        .tick                 (tick),
        .core_spike_in        (c1_spike_in),
        .core_spike_out_valid (c1_aer_tx_valid),
        .core_spike_out_addr  (c1_aer_tx_addr),
        .noc_rx_valid         (broadcast_valid),
        .noc_rx_packet        (broadcast_packet),
        .noc_tx_valid         (c1_tx_valid),
        .noc_tx_packet        (c1_tx_packet),
        .noc_tx_grant         (c1_tx_grant),
        .host_wr_en           (c1_ni_wr_en),
        .host_wr_addr         (ni_wr_addr),
        .host_wr_data         (ni_wr_data)
    );

    lif_neuron_array u_core_1 (
        .clk             (clk),
        .rst_n           (rst_n),
        .tick            (tick),
        .ready           (ready_cores[1]),
        .spike_in        (c1_spike_in),
        .wr_en           (c1_sram_wr_en),
        .wr_addr         (sram_wr_addr),
        .wr_data         (host_wr_data),
        .threshold       (threshold),
        .leak_rate       (leak_rate),
        .reset_mode      (reset_mode),
        .aer_tx_valid    (c1_aer_tx_valid),
        .aer_tx_addr     (c1_aer_tx_addr)
    );

    // ==========================================
    // CORE 2
    // ==========================================
    wire [63:0] c2_spike_in;
    wire        c2_aer_tx_valid;
    wire [4:0]  c2_aer_tx_addr;

    network_interface #(.CORE_ID(2'd2)) u_ni_2 (
        .clk                  (clk),
        .rst_n                (rst_n),
        .tick                 (tick),
        .core_spike_in        (c2_spike_in),
        .core_spike_out_valid (c2_aer_tx_valid),
        .core_spike_out_addr  (c2_aer_tx_addr),
        .noc_rx_valid         (broadcast_valid),
        .noc_rx_packet        (broadcast_packet),
        .noc_tx_valid         (c2_tx_valid),
        .noc_tx_packet        (c2_tx_packet),
        .noc_tx_grant         (c2_tx_grant),
        .host_wr_en           (c2_ni_wr_en),
        .host_wr_addr         (ni_wr_addr),
        .host_wr_data         (ni_wr_data)
    );

    lif_neuron_array u_core_2 (
        .clk             (clk),
        .rst_n           (rst_n),
        .tick            (tick),
        .ready           (ready_cores[2]),
        .spike_in        (c2_spike_in),
        .wr_en           (c2_sram_wr_en),
        .wr_addr         (sram_wr_addr),
        .wr_data         (host_wr_data),
        .threshold       (threshold),
        .leak_rate       (leak_rate),
        .reset_mode      (reset_mode),
        .aer_tx_valid    (c2_aer_tx_valid),
        .aer_tx_addr     (c2_aer_tx_addr)
    );

    // ==========================================
    // CORE 3
    // ==========================================
    wire [63:0] c3_spike_in;
    wire        c3_aer_tx_valid;
    wire [4:0]  c3_aer_tx_addr;

    network_interface #(.CORE_ID(2'd3)) u_ni_3 (
        .clk                  (clk),
        .rst_n                (rst_n),
        .tick                 (tick),
        .core_spike_in        (c3_spike_in),
        .core_spike_out_valid (c3_aer_tx_valid),
        .core_spike_out_addr  (c3_aer_tx_addr),
        .noc_rx_valid         (broadcast_valid),
        .noc_rx_packet        (broadcast_packet),
        .noc_tx_valid         (c3_tx_valid),
        .noc_tx_packet        (c3_tx_packet),
        .noc_tx_grant         (c3_tx_grant),
        .host_wr_en           (c3_ni_wr_en),
        .host_wr_addr         (ni_wr_addr),
        .host_wr_data         (ni_wr_data)
    );

    lif_neuron_array u_core_3 (
        .clk             (clk),
        .rst_n           (rst_n),
        .tick            (tick),
        .ready           (ready_cores[3]),
        .spike_in        (c3_spike_in),
        .wr_en           (c3_sram_wr_en),
        .wr_addr         (sram_wr_addr),
        .wr_data         (host_wr_data),
        .threshold       (threshold),
        .leak_rate       (leak_rate),
        .reset_mode      (reset_mode),
        .aer_tx_valid    (c3_aer_tx_valid),
        .aer_tx_addr     (c3_aer_tx_addr)
    );

endmodule
