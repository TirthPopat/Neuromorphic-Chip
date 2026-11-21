// stdp_engine.v
// Evaluates STDP weight updates for a 4-weight vector chunk.
// Uses a Learn-on-Fire Hebbian rule.

module stdp_engine #(
    parameter WEIGHT_WIDTH = 8,
    parameter signed [WEIGHT_WIDTH-1:0] LTP_RATE = 8'sd2,
    parameter signed [WEIGHT_WIDTH-1:0] LTD_RATE = 8'sd1
)(
    input  wire [31:0] weight_vec_in,
    input  wire [3:0]  spike_bits,
    
    output wire [31:0] weight_vec_out
);

    wire signed [WEIGHT_WIDTH-1:0] w_in [0:3];
    reg  signed [WEIGHT_WIDTH-1:0] w_out [0:3];
    
    assign w_in[0] = weight_vec_in[7:0];
    assign w_in[1] = weight_vec_in[15:8];
    assign w_in[2] = weight_vec_in[23:16];
    assign w_in[3] = weight_vec_in[31:24];

    integer i;
    always @(*) begin
        for (i = 0; i < 4; i = i + 1) begin
            if (spike_bits[i]) begin
                // Long-Term Potentiation (LTP)
                if (w_in[i] > (127 - LTP_RATE)) 
                    w_out[i] = 8'sd127; // Saturate max
                else
                    w_out[i] = w_in[i] + LTP_RATE;
            end else begin
                // Long-Term Depression (LTD)
                if (w_in[i] < (-128 + LTD_RATE))
                    w_out[i] = -8'sd128; // Saturate min
                else
                    w_out[i] = w_in[i] - LTD_RATE;
            end
        end
    end

    assign weight_vec_out = {w_out[3], w_out[2], w_out[1], w_out[0]};

endmodule
