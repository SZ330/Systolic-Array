// A = [ [1, 2],
//       [3, 4] ]

// B = [ [5, 6],
//       [7, 8] ]

// C = [ [19, 22],
//       [43, 50] ]

module tb_grid;

    localparam int ROWS   = 2;
    localparam int COLS   = 2;
    localparam int DATA_W = 8;
    localparam int ACC_W  = 32;

    logic clk_i;
    logic reset_i;

    logic signed [DATA_W-1:0] a_left_i [ROWS];
    logic signed [DATA_W-1:0] b_top_i  [COLS];
    logic a_valid_left_i [ROWS];
    logic b_valid_top_i  [COLS];
    logic accumulator_clear_i [ROWS][COLS];

    logic signed [ACC_W-1:0] psum_o [ROWS][COLS];

    localparam int signed EXPECTED_C [ROWS][COLS] = '{
        '{19, 22},
        '{43, 50}
    };

    initial begin
        //dump fsdb
        $fsdbDumpfile("tb_grid.fsdb");
        $fsdbDumpvars("+all");
    end

    grid #(
        .ROWS(ROWS),
        .COLS(COLS),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) dut (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .a_left_i(a_left_i),
        .b_top_i(b_top_i),
        .a_valid_left_i(a_valid_left_i),
        .b_valid_top_i(b_valid_top_i),
        .accumulator_clear_i(accumulator_clear_i),
        .psum_o(psum_o)
    );

    always #5 clk_i = ~clk_i;

    initial begin
        clk_i = 0;
        reset_i = 1;

        a_left_i[0] = 0; a_left_i[1] = 0;
        b_top_i[0]  = 0; b_top_i[1]  = 0;
        a_valid_left_i[0] = 0; a_valid_left_i[1] = 0;
        b_valid_top_i[0]  = 0; b_valid_top_i[1]  = 0;

        accumulator_clear_i[0][0] = 1;
        accumulator_clear_i[0][1] = 1;
        accumulator_clear_i[1][0] = 1;
        accumulator_clear_i[1][1] = 1;

        #12;
        reset_i = 0;

        #10;
        accumulator_clear_i[0][0] = 0;
        accumulator_clear_i[0][1] = 0;
        accumulator_clear_i[1][0] = 0;
        accumulator_clear_i[1][1] = 0;

        // Drive skewed wavefront inputs so operands meet at each PE in the
        // same cycle after the registered right/down propagation.

        // cycle 0
        a_left_i[0] = 1; a_left_i[1] = 0;
        b_top_i[0]  = 5; b_top_i[1]  = 0;
        a_valid_left_i[0] = 1; a_valid_left_i[1] = 0;
        b_valid_top_i[0]  = 1; b_valid_top_i[1]  = 0;
        #10;

        // cycle 1
        a_left_i[0] = 2; a_left_i[1] = 3;
        b_top_i[0]  = 7; b_top_i[1]  = 6;
        a_valid_left_i[0] = 1; a_valid_left_i[1] = 1;
        b_valid_top_i[0]  = 1; b_valid_top_i[1]  = 1;
        #10;

        // cycle 2
        a_left_i[0] = 0; a_left_i[1] = 4;
        b_top_i[0]  = 0; b_top_i[1]  = 8;
        a_valid_left_i[0] = 0; a_valid_left_i[1] = 1;
        b_valid_top_i[0]  = 0; b_valid_top_i[1]  = 1;
        #10;

        // stop driving valid data
        a_valid_left_i[0] = 0; a_valid_left_i[1] = 0;
        b_valid_top_i[0]  = 0; b_valid_top_i[1]  = 0;
        a_left_i[0] = 0; a_left_i[1] = 0;
        b_top_i[0]  = 0; b_top_i[1]  = 0;

        #40;

        $display("");
        $display("========================================");
        $display("Systolic array result matrix C:");
        $display("[ %0d  %0d ]", psum_o[0][0], psum_o[0][1]);
        $display("[ %0d  %0d ]", psum_o[1][0], psum_o[1][1]);
        $display("Expected matrix C:");
        $display("[ %0d  %0d ]", EXPECTED_C[0][0], EXPECTED_C[0][1]);
        $display("[ %0d  %0d ]", EXPECTED_C[1][0], EXPECTED_C[1][1]);

        if ((psum_o[0][0] === EXPECTED_C[0][0]) &&
            (psum_o[0][1] === EXPECTED_C[0][1]) &&
            (psum_o[1][0] === EXPECTED_C[1][0]) &&
            (psum_o[1][1] === EXPECTED_C[1][1])) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED");
        end
        $display("========================================");

        $finish;
    end

endmodule
