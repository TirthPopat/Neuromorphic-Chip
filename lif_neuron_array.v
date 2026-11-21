// lif_neuron_array.v
// Top-level neuromorphic core with STDP Learning Engine

module lif_neuron_array #(
    parameter NUM_NEURONS  = 32,
    parameter NUM_INPUTS   = 64,
    parameter NUM_CHUNKS   = 16,
    parameter WEIGHT_WIDTH = 8,
    parameter MEM_WIDTH    = 20,
    parameter NEURON_ADDR_W = 5,
    parameter CHUNK_ADDR_W  = 4,
    parameter WEIGHT_ADDR_W = 9
)(
    input  wire                             clk,
    input  wire                             rst_n,

    // Time-multiplexed control
    input  wire                             tick,
    output wire                             ready,

    // Input spikes
    input  wire [NUM_INPUTS-1:0]            spike_in,

    // Host weight programming interface (overridden by STDP during eval)
    input  wire                             wr_en,
    input  wire [WEIGHT_ADDR_W-1:0]         wr_addr,
    input  wire [31:0]                      wr_data,

    // Global parameters
    input  wire signed [MEM_WIDTH-1:0]      threshold,
    input  wire signed [MEM_WIDTH-1:0]      leak_rate,
    input  wire                             reset_mode,

    // Output AER Spikes
    output wire                             aer_tx_valid,
    output wire [NEURON_ADDR_W-1:0]         aer_tx_addr
);

    wire                     weight_read_en;
    wire [WEIGHT_ADDR_W-1:0] weight_addr;
    wire                     mac_valid;
    wire                     mac_clear;
    wire [CHUNK_ADDR_W-1:0]  mac_chunk_sel;
    wire                     mem_read_en;
    wire [NEURON_ADDR_W-1:0] mem_rd_addr;
    wire                     mem_write_en;
    wire [NEURON_ADDR_W-1:0] mem_wr_addr;
    wire [NEURON_ADDR_W-1:0] spike_out_addr;
    wire                     spike_out_valid;
    
    wire                     stdp_write_en;
    wire [WEIGHT_ADDR_W-1:0] stdp_wr_addr;
    wire [CHUNK_ADDR_W-1:0]  stdp_chunk_sel;
    
    wire [31:0]                        weight_vec_read;
    wire [31:0]                        weight_vec_learned;
    wire signed [MEM_WIDTH-1:0]        membrane_in;
    wire signed [MEM_WIDTH-1:0]        next_membrane;
    wire                               fire;

    // --- Controller ---
    tm_controller #(
        .NUM_NEURONS   (NUM_NEURONS),
        .NUM_CHUNKS    (NUM_CHUNKS),
        .NEURON_ADDR_W (NEURON_ADDR_W),
        .CHUNK_ADDR_W  (CHUNK_ADDR_W),
        .WEIGHT_ADDR_W (WEIGHT_ADDR_W)
    ) u_controller (
        .clk             (clk),
        .rst_n           (rst_n),
        .tick            (tick),
        .ready           (ready),
        .weight_read_en  (weight_read_en),
        .weight_addr     (weight_addr),
        .stdp_write_en   (stdp_write_en),
        .stdp_wr_addr    (stdp_wr_addr),
        .stdp_chunk_sel  (stdp_chunk_sel),
        .mac_valid       (mac_valid),
        .mac_clear       (mac_clear),
        .mac_chunk_sel   (mac_chunk_sel),
        .mem_read_en     (mem_read_en),
        .mem_rd_addr     (mem_rd_addr),
        .mem_write_en    (mem_write_en),
        .mem_wr_addr     (mem_wr_addr),
        .spike_out_addr  (spike_out_addr),
        .spike_out_valid (spike_out_valid),
        .neuron_fire     (fire)
    );
    
    // --- STDP Engine ---
    wire [3:0] stdp_spike_bits = spike_in[stdp_chunk_sel*4 +: 4];
    
    // STDP takes the read weight vector, and applies the delta based on spike_in
    stdp_engine #(
        .WEIGHT_WIDTH (WEIGHT_WIDTH),
        .LTP_RATE     (8'sd2),
        .LTD_RATE     (8'sd1)
    ) u_stdp (
        .weight_vec_in  (weight_vec_read),
        .spike_bits     (stdp_spike_bits),
        .weight_vec_out (weight_vec_learned)
    );

    // --- Mux Port 0 (Host vs STDP) ---
    // Note: STDP write enable has priority over host writes during evaluation
    wire                     final_wr_en   = ready ? wr_en : stdp_write_en;
    wire [WEIGHT_ADDR_W-1:0] final_wr_addr = ready ? wr_addr : stdp_wr_addr;
    wire [31:0]              final_wr_data = ready ? wr_data : weight_vec_learned;

    // --- Weight Memory (Hard Macro) ---
    weight_sram u_weight_sram (
        .clk    (clk),
        .csb0   (~final_wr_en),
        .web0   (~final_wr_en),
        .addr0  (final_wr_addr),
        .din0   (final_wr_data),
        
        .csb1   (~weight_read_en),
        .addr1  (weight_addr),
        .dout1  (weight_vec_read)
    );

    // --- Membrane Memory (Regfile) ---
    membrane_mem #(
        .MEM_WIDTH   (MEM_WIDTH),
        .NUM_NEURONS (NUM_NEURONS),
        .ADDR_WIDTH  (NEURON_ADDR_W)
    ) u_membrane_mem (
        .clk      (clk),
        .rst_n    (rst_n),
        .rd_addr  (mem_rd_addr),
        .rd_data  (membrane_in),
        .wr_en    (mem_write_en),
        .wr_addr  (mem_wr_addr),
        .wr_data  (next_membrane)
    );

    wire [3:0] spike_bits = spike_in[mac_chunk_sel*4 +: 4];

    // --- Vector Datapath Core ---
    lif_neuron_core #(
        .WEIGHT_WIDTH (WEIGHT_WIDTH),
        .MEM_WIDTH    (MEM_WIDTH)
    ) u_datapath (
        .clk           (clk),
        .rst_n         (rst_n),
        .mac_valid     (mac_valid),
        .mac_clear     (mac_clear),
        .spike_bits    (spike_bits),
        .weight_vec    (weight_vec_read),
        .membrane_in   (membrane_in),
        .threshold     (threshold),
        .leak_rate     (leak_rate),
        .reset_mode    (reset_mode),
        .fire          (fire),
        .next_membrane (next_membrane)
    );

    // --- Output AER Packet ---
    assign aer_tx_valid = spike_out_valid && fire;
    assign aer_tx_addr  = spike_out_addr;

endmodule
