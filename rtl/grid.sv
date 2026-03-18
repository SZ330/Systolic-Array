// Systolic array grid

module grid #(
    // Number of PE rows in the array. This also equals the number of A values injected from the left each cycle.
    parameter int ROWS   = 2,

    // Number of PE columns in the array. This also equals the number of B values injected from the top each cycle.
    parameter int COLS   = 2,

    // Bit width of each signed input operand.
    parameter int DATA_W = 8,

    // Bit width of one multiply result.
    parameter int PROD_W = 2 * DATA_W,

    // Bit width of each PE accumulator / partial sum register.
    // This must be large enough to hold the sum of multiple products.
    parameter int ACC_W  = 32
) (
    input  logic clk_i,
    input  logic reset_i,

    // Left-edge A inputs.
    // One A value is injected into each row and then propagated to the right.
    input  logic signed [DATA_W-1:0] a_left_i [ROWS],

    // Top-edge B inputs.
    // One B value is injected into each column and then propagated downward.
    input  logic signed [DATA_W-1:0] b_top_i [COLS],

    // Valid flags for the left-edge A inputs. These travel with A data across the array.
    input  logic a_valid_left_i [ROWS],

    // Valid flags for the top-edge B inputs. These travel with B data down the array.
    input  logic b_valid_top_i [COLS],

    // Per-PE accumulator clear controls.
    // Used to reset local accumulators before a new tile or computation phase.
    input  logic accumulator_clear_i [ROWS][COLS],

    // Accumulated outputs from each PE.
    // In an output-stationary array, each PE holds one output element locally.
    output logic signed [ACC_W-1:0] psum_o [ROWS][COLS]
);

    // Horizontal interconnect for A operands.
    // Each row has COLS+1 tap points:
    // - column 0 is driven by the left-edge input for that row
    // - each PE forwards its registered A value to the next column to the right
    logic signed [DATA_W-1:0] a_bus [ROWS][COLS+1];

    // Vertical interconnect for B operands.
    // Each column has ROWS+1 tap points:
    // - row 0 is driven by the top-edge input for that column
    // - each PE forwards its registered B value to the next row below
    logic signed [DATA_W-1:0] b_bus [ROWS+1][COLS];

    // Valid signals travel with the A data as it moves horizontally.
    // This lets each PE know whether the incoming A operand is meaningful.
    logic a_valid_bus [ROWS][COLS+1];

    // Valid signals travel with the B data as it moves vertically.
    // A multiply-accumulate should only happen when both incoming valids align.
    logic b_valid_bus [ROWS+1][COLS];

    genvar row;
    genvar col;

    generate
        // Inject the left-edge A inputs into the first column of the array.
        // These signals are the starting point for each row's horizontal flow.
        for (row = 0; row < ROWS; row++) begin : gen_a_edges
            assign a_bus[row][0]       = a_left_i[row];
            assign a_valid_bus[row][0] = a_valid_left_i[row];
        end

        // Inject the top-edge B inputs into the first row of the array.
        // These signals are the starting point for each column's vertical flow.
        for (col = 0; col < COLS; col++) begin : gen_b_edges
            assign b_bus[0][col]       = b_top_i[col];
            assign b_valid_bus[0][col] = b_valid_top_i[col];
        end

        // Build the ROWS x COLS grid of processing elements.
        // Each PE:
        // - consumes one A operand from its left
        // - consumes one B operand from its top
        // - accumulates into its own stationary partial sum
        // - forwards A to the right and B downward on the next cycle
        for (row = 0; row < ROWS; row++) begin : gen_rows
            for (col = 0; col < COLS; col++) begin : gen_cols
                pe #(
                    .DATA_W(DATA_W),
                    .PROD_W(PROD_W),
                    .ACC_W (ACC_W)
                ) pe_inst (
                    .clk_i(clk_i),
                    .reset_i(reset_i),
                    .a_in(a_bus[row][col]),
                    .b_in(b_bus[row][col]),
                    .a_valid_in(a_valid_bus[row][col]),
                    .b_valid_in(b_valid_bus[row][col]),

                    // Each PE gets an independent clear so a controller can
                    // reset accumulators at tile boundaries or during startup.
                    .accumulator_clear(accumulator_clear_i[row][col]),

                    // Forwarding paths form the systolic wavefront:
                    // A propagates left-to-right, B propagates top-to-bottom.
                    .a_out(a_bus[row][col+1]),
                    .b_out(b_bus[row+1][col]),
                    .a_valid_out(a_valid_bus[row][col+1]),
                    .b_valid_out(b_valid_bus[row+1][col]),

                    // Output-stationary behavior: each PE keeps and exposes
                    // its own accumulated result for one output matrix element.
                    .psum_out(psum_o[row][col])
                );
            end
        end
    endgenerate

endmodule
