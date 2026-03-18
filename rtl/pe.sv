// One processing element (PE) in the systolic array.
// In an output-stationary design, the partial sum stays in this PE while:
// - A operands move left-to-right across the row
// - B operands move top-to-bottom across the column

module pe #(
    parameter int DATA_W = 8,           // Width of each input operands
    parameter int PROD_W = 2 * DATA_W,  // Width of the multiply result
    parameter int ACC_W  = 32           // Width of the running partial sum register
) (
    input  logic clk_i,
    input  logic reset_i,
    input  logic signed [DATA_W-1:0] a_in,
    input  logic signed [DATA_W-1:0] b_in,
    input  logic a_valid_in,
    input  logic b_valid_in,
    input  logic accumulator_clear,

    output logic signed [DATA_W-1:0] a_out,
    output logic signed [DATA_W-1:0] b_out,
    output logic a_valid_out,
    output logic b_valid_out,
    output logic signed [ACC_W-1:0] psum_out
);

    // Combinational multiply of the current input operands.
    // Result of A x B
    logic signed [PROD_W-1:0] product;

    assign product = a_in * b_in;

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            // Reset the forwarding path and local accumulator so the PE starts
            // in a known idle state.
            a_out       <= 0;
            b_out       <= 0;
            a_valid_out <= 0;
            b_valid_out <= 0;
            psum_out    <= 0;
        end else begin
            // Forward incoming operands and their valid flags to neighbors.
            // These outputs are registered, so data advances one PE per cycle.
            a_out       <= a_in;
            b_out       <= b_in;
            a_valid_out <= a_valid_in;
            b_valid_out <= b_valid_in;

            // Clear takes priority so a controller can reset the local output
            // element before starting a new tile or computation phase.
            if (accumulator_clear) begin
                psum_out <= 0;

            // Only accumulate when both incoming operands are valid.
            // This prevents adding meaningless values during fill/drain cycles.
            end else if (a_valid_in && b_valid_in) begin
                // The signed product is added into the wider signed accumulator.
                psum_out <= psum_out + product;
            end
        end
    end

endmodule

