// tm_controller.v
// Controller with Forward Pass and Learn-on-Fire Pass

module tm_controller #(
    parameter NUM_NEURONS   = 32,
    parameter NUM_CHUNKS    = 16,
    parameter NEURON_ADDR_W = 5,
    parameter CHUNK_ADDR_W  = 4,
    parameter WEIGHT_ADDR_W = 9
)(
    input  wire                   clk,
    input  wire                   rst_n,
    
    input  wire                   tick,
    output reg                    ready,
    
    // SRAM Address generation (Read Port 1)
    output reg                    weight_read_en,
    output reg  [WEIGHT_ADDR_W-1:0] weight_addr,
    
    // SRAM Write generation (Write Port 0 - STDP)
    output reg                    stdp_write_en,
    output reg  [WEIGHT_ADDR_W-1:0] stdp_wr_addr,
    output reg  [CHUNK_ADDR_W-1:0]  stdp_chunk_sel,
    
    // MAC control
    output reg                    mac_valid,
    output reg                    mac_clear,
    output reg  [CHUNK_ADDR_W-1:0] mac_chunk_sel,
    
    // Membrane Address generation
    output reg                    mem_read_en,
    output reg  [NEURON_ADDR_W-1:0] mem_rd_addr,
    
    output reg                    mem_write_en,
    output reg  [NEURON_ADDR_W-1:0] mem_wr_addr,
    
    // Neuron index tracking for spike demux
    output reg  [NEURON_ADDR_W-1:0] spike_out_addr,
    output reg                    spike_out_valid,
    
    // Feedback from datapath
    input  wire                   neuron_fire
);

    localparam S_IDLE      = 3'd0,
               S_FORWARD   = 3'd1,
               S_EVAL      = 3'd2,
               S_LEARN     = 3'd3,
               S_LEARN_END = 3'd4;

    reg [2:0] state;
    reg [NEURON_ADDR_W-1:0] neuron_cnt;
    reg [CHUNK_ADDR_W-1:0]  chunk_cnt;
    
    reg [NEURON_ADDR_W-1:0] pipe_neuron_c1, pipe_neuron_c2, pipe_neuron_c3;
    reg [CHUNK_ADDR_W-1:0]  pipe_chunk_c1, pipe_chunk_c2, pipe_chunk_c3;
    reg                     pipe_valid_c1, pipe_valid_c2, pipe_valid_c3;
    
    // STDP Pipeline
    reg [WEIGHT_ADDR_W-1:0] stdp_addr_c1, stdp_addr_c2;
    reg [CHUNK_ADDR_W-1:0]  stdp_chunk_c1, stdp_chunk_c2;
    reg                     stdp_valid_c1, stdp_valid_c2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_IDLE;
            ready          <= 1'b1;
            neuron_cnt     <= 0;
            chunk_cnt      <= 0;
            
            weight_read_en <= 0;
            weight_addr    <= 0;
            
            pipe_valid_c1  <= 0;
            pipe_valid_c2  <= 0;
            pipe_valid_c3  <= 0;
            
            stdp_write_en  <= 0;
            stdp_wr_addr   <= 0;
            stdp_chunk_sel <= 0;
            stdp_valid_c1  <= 0;
            stdp_valid_c2  <= 0;
            
            stdp_chunk_c1  <= 0;
            stdp_chunk_c2  <= 0;
        end else begin
            // Default pulse signals
            stdp_write_en <= 0;
            
            // Forward pipeline shift
            pipe_valid_c2  <= pipe_valid_c1;
            pipe_neuron_c2 <= pipe_neuron_c1;
            pipe_chunk_c2  <= pipe_chunk_c1;
            
            pipe_valid_c3  <= pipe_valid_c2;
            pipe_neuron_c3 <= pipe_neuron_c2;
            pipe_chunk_c3  <= pipe_chunk_c2;
            
            // STDP pipeline shift
            stdp_valid_c2 <= stdp_valid_c1;
            stdp_addr_c2  <= stdp_addr_c1;
            stdp_chunk_c2 <= stdp_chunk_c1;
            
            if (stdp_valid_c2) begin
                stdp_write_en  <= 1'b1;
                stdp_wr_addr   <= stdp_addr_c2;
                stdp_chunk_sel <= stdp_chunk_c2;
            end

            case (state)
                S_IDLE: begin
                    if (tick) begin
                        ready          <= 1'b0;
                        state          <= S_FORWARD;
                        neuron_cnt     <= 0;
                        chunk_cnt      <= 0;
                        weight_read_en <= 1'b1;
                        weight_addr    <= 0;
                        pipe_valid_c1  <= 1'b1;
                        pipe_neuron_c1 <= 0;
                        pipe_chunk_c1  <= 0;
                    end
                end
                
                S_FORWARD: begin
                    if (chunk_cnt == NUM_CHUNKS - 1) begin
                        weight_read_en <= 1'b0;
                        pipe_valid_c1  <= 1'b0;
                        state          <= S_EVAL;
                    end else begin
                        chunk_cnt      <= chunk_cnt + 1;
                        weight_addr    <= {neuron_cnt, chunk_cnt + 1'b1};
                        pipe_valid_c1  <= 1'b1;
                        pipe_neuron_c1 <= neuron_cnt;
                        pipe_chunk_c1  <= chunk_cnt + 1'b1;
                    end
                end
                
                S_EVAL: begin
                    pipe_valid_c1 <= 1'b0;
                    // Wait until pipe_valid_c3 is high and processing the last chunk
                    if (pipe_valid_c3 && pipe_chunk_c3 == NUM_CHUNKS - 1) begin
                        if (neuron_fire) begin
                            state          <= S_LEARN;
                            chunk_cnt      <= 0;
                            weight_read_en <= 1'b1;
                            weight_addr    <= {neuron_cnt, 4'd0};
                            stdp_valid_c1  <= 1'b1;
                            stdp_addr_c1   <= {neuron_cnt, 4'd0};
                            stdp_chunk_c1  <= 0;
                        end else begin
                            if (neuron_cnt == NUM_NEURONS - 1) begin
                                state <= S_IDLE;
                                ready <= 1'b1;
                            end else begin
                                state          <= S_FORWARD;
                                neuron_cnt     <= neuron_cnt + 1;
                                chunk_cnt      <= 0;
                                weight_read_en <= 1'b1;
                                weight_addr    <= {neuron_cnt + 1'b1, 4'd0};
                                pipe_valid_c1  <= 1'b1;
                                pipe_neuron_c1 <= neuron_cnt + 1'b1;
                                pipe_chunk_c1  <= 0;
                            end
                        end
                    end
                end
                
                S_LEARN: begin
                    if (chunk_cnt == NUM_CHUNKS - 1) begin
                        weight_read_en <= 1'b0;
                        stdp_valid_c1  <= 1'b0;
                        state          <= S_LEARN_END;
                    end else begin
                        chunk_cnt      <= chunk_cnt + 1;
                        weight_addr    <= {neuron_cnt, chunk_cnt + 1'b1};
                        stdp_valid_c1  <= 1'b1;
                        stdp_addr_c1   <= {neuron_cnt, chunk_cnt + 1'b1};
                        stdp_chunk_c1  <= chunk_cnt + 1'b1;
                    end
                end
                
                S_LEARN_END: begin
                    // Wait for STDP writes to finish
                    if (!stdp_valid_c1 && !stdp_valid_c2 && !stdp_write_en) begin
                        if (neuron_cnt == NUM_NEURONS - 1) begin
                            state <= S_IDLE;
                            ready <= 1'b1;
                        end else begin
                            state          <= S_FORWARD;
                            neuron_cnt     <= neuron_cnt + 1;
                            chunk_cnt      <= 0;
                            weight_read_en <= 1'b1;
                            weight_addr    <= {neuron_cnt + 1'b1, 4'd0};
                            pipe_valid_c1  <= 1'b1;
                            pipe_neuron_c1 <= neuron_cnt + 1'b1;
                            pipe_chunk_c1  <= 0;
                        end
                    end
                end
            endcase
        end
    end
    
    always @(*) begin
        mac_valid     = pipe_valid_c2;
        mac_clear     = (pipe_chunk_c2 == 0);
        mac_chunk_sel = pipe_chunk_c2;
        
        mem_read_en = pipe_valid_c2 && (pipe_chunk_c2 == NUM_CHUNKS - 1);
        mem_rd_addr = pipe_neuron_c2;
        
        mem_write_en = pipe_valid_c3 && (pipe_chunk_c3 == NUM_CHUNKS - 1);
        mem_wr_addr  = pipe_neuron_c3;
        
        spike_out_valid = pipe_valid_c3 && (pipe_chunk_c3 == NUM_CHUNKS - 1);
        spike_out_addr  = pipe_neuron_c3;
    end

endmodule
