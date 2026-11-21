// membrane_accumulator.v
// Membrane Accumulator block (Purely Combinational for TM Architecture)
// Computes V_candidate = leak(membrane_in) + I_syn.

module membrane_accumulator #(
    parameter MEM_WIDTH = 20
)(
    input  wire signed [MEM_WIDTH-1:0] membrane_in,
    input  wire signed [MEM_WIDTH-1:0] synaptic_current,
    input  wire signed [MEM_WIDTH-1:0] leak_rate,
    
    output wire signed [MEM_WIDTH-1:0] v_candidate
);

    wire signed [MEM_WIDTH-1:0] leaked;

    // Leak toward zero without sign flip / overshoot
    assign leaked = (membrane_in > leak_rate)   ? (membrane_in - leak_rate) :
                    (membrane_in < -leak_rate)  ? (membrane_in + leak_rate) :
                                                  {MEM_WIDTH{1'b0}};

    // Candidate = leaked membrane + synaptic current
    assign v_candidate = leaked + synaptic_current;

endmodule
