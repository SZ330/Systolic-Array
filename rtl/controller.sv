// Controller for an output-stationary systolic array.
//
// This module sequences one matrix-multiply tile through the array by:
// - clearing all PE accumulators before a new run
// - injecting A and B operands at the array boundaries
// - skewing the boundary inputs so operands meet at the correct PE
// - reporting when the array is busy and when the tile is complete
//
// The controller assumes:
// - matrix A has shape ROWS x INNER_DIM
// - matrix B has shape INNER_DIM x COLS
// - each PE forwards A to the right and B downward with one-cycle latency
module controller #(
    parameter int ROWS      = 2,
    parameter int COLS      = 2,
    parameter int DATA_W    = 8,
    parameter int INNER_DIM = 2
) (
    input  logic clk_i,
    input  logic reset_i,
    input  logic start_i,

    // Matrix A is shaped ROWS x INNER_DIM.
    input  logic signed [DATA_W-1:0] a_matrix_i [ROWS][INNER_DIM],

    // Matrix B is shaped INNER_DIM x COLS.
    input  logic signed [DATA_W-1:0] b_matrix_i [INNER_DIM][COLS],

    // Drive signals for the systolic array boundary.
    output logic signed [DATA_W-1:0] a_left_o [ROWS],
    output logic signed [DATA_W-1:0] b_top_o  [COLS],
    output logic a_valid_left_o [ROWS],
    output logic b_valid_top_o  [COLS],
    output logic accumulator_clear_o [ROWS][COLS],

    // Status.
    output logic busy_o,
    output logic done_o
);

    // Number of cycles during which boundary inputs may still need to be
    // driven. The extra skew comes from rows/columns starting at different
    // times so data aligns inside the array.
    localparam int FEED_CYCLES  = INNER_DIM + ((ROWS > COLS) ? ROWS : COLS) - 1;

    // Total run length from the first injected operands until the last MAC
    // opportunity reaches the bottom-right PE.
    localparam int TOTAL_CYCLES = INNER_DIM + ROWS + COLS - 2;

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_CLEAR,
        ST_RUN,
        ST_DONE
    } state_t;

    state_t state_r, state_n;
    int cycle_count_r, cycle_count_n;

    // State and cycle counter registers.
    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            state_r       <= ST_IDLE;
            cycle_count_r <= 0;
        end else begin
            state_r       <= state_n;
            cycle_count_r <= cycle_count_n;
        end
    end

    // Next-state logic for the controller FSM.
    //
    // ST_IDLE  : wait for a start pulse
    // ST_CLEAR : clear all PE accumulators for one cycle
    // ST_RUN   : stream skewed A/B data into the array
    // ST_DONE  : pulse done for one cycle, then return to idle
    always_comb begin
        state_n       = state_r;
        cycle_count_n = cycle_count_r;

        unique case (state_r)
            ST_IDLE: begin
                cycle_count_n = 0;
                if (start_i) begin
                    state_n = ST_CLEAR;
                end
            end

            ST_CLEAR: begin
                cycle_count_n = 0;
                state_n       = ST_RUN;
            end

            ST_RUN: begin
                if (cycle_count_r == (TOTAL_CYCLES - 1)) begin
                    cycle_count_n = 0;
                    state_n       = ST_DONE;
                end else begin
                    cycle_count_n = cycle_count_r + 1;
                end
            end

            ST_DONE: begin
                state_n = ST_IDLE;
            end

            default: begin
                state_n       = ST_IDLE;
                cycle_count_n = 0;
            end
        endcase
    end

    // Output generation.
    //
    // Default outputs are zero/inactive. During ST_RUN, each row and column
    // computes which k-index should be injected on the current cycle based on
    // the skewed schedule:
    //   row r receives A[r][cycle-r]
    //   col c receives B[cycle-c][c]
    // whenever that index is inside the valid INNER_DIM range.
    always_comb begin
        int row;
        int col;
        int k_idx;

        done_o = (state_r == ST_DONE);
        busy_o = (state_r != ST_IDLE);

        for (row = 0; row < ROWS; row++) begin
            a_left_o[row]       = '0;
            a_valid_left_o[row] = 1'b0;
        end

        for (col = 0; col < COLS; col++) begin
            b_top_o[col]       = '0;
            b_valid_top_o[col] = 1'b0;
        end

        for (row = 0; row < ROWS; row++) begin
            for (col = 0; col < COLS; col++) begin
                accumulator_clear_o[row][col] = (state_r == ST_CLEAR);
            end
        end

        if (state_r == ST_RUN) begin
            for (row = 0; row < ROWS; row++) begin
                k_idx = cycle_count_r - row;
                if ((cycle_count_r < FEED_CYCLES) &&
                    (k_idx >= 0) &&
                    (k_idx < INNER_DIM)) begin
                    a_left_o[row]       = a_matrix_i[row][k_idx];
                    a_valid_left_o[row] = 1'b1;
                end
            end

            for (col = 0; col < COLS; col++) begin
                k_idx = cycle_count_r - col;
                if ((cycle_count_r < FEED_CYCLES) &&
                    (k_idx >= 0) &&
                    (k_idx < INNER_DIM)) begin
                    b_top_o[col]       = b_matrix_i[k_idx][col];
                    b_valid_top_o[col] = 1'b1;
                end
            end
        end
    end

endmodule
