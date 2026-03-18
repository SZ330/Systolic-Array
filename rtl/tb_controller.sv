module tb_controller;

    localparam int ROWS      = 2;
    localparam int COLS      = 2;
    localparam int DATA_W    = 8;
    localparam int INNER_DIM = 2;

    logic clk_i;
    logic reset_i;
    logic start_i;

    logic signed [DATA_W-1:0] a_matrix_i [ROWS][INNER_DIM];
    logic signed [DATA_W-1:0] b_matrix_i [INNER_DIM][COLS];

    logic signed [DATA_W-1:0] a_left_o [ROWS];
    logic signed [DATA_W-1:0] b_top_o  [COLS];
    logic a_valid_left_o [ROWS];
    logic b_valid_top_o  [COLS];
    logic accumulator_clear_o [ROWS][COLS];
    logic busy_o;
    logic done_o;

    
    initial begin
        //dump fsdb
        $fsdbDumpfile("tb_controller.fsdb");
        $fsdbDumpvars("+all");
    end

    controller #(
        .ROWS(ROWS),
        .COLS(COLS),
        .DATA_W(DATA_W),
        .INNER_DIM(INNER_DIM)
    ) dut (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .start_i(start_i),
        .a_matrix_i(a_matrix_i),
        .b_matrix_i(b_matrix_i),
        .a_left_o(a_left_o),
        .b_top_o(b_top_o),
        .a_valid_left_o(a_valid_left_o),
        .b_valid_top_o(b_valid_top_o),
        .accumulator_clear_o(accumulator_clear_o),
        .busy_o(busy_o),
        .done_o(done_o)
    );

    always #5 clk_i = ~clk_i;

    task automatic check_outputs(
        input string label,
        input int exp_a0,
        input int exp_a1,
        input int exp_b0,
        input int exp_b1,
        input bit exp_av0,
        input bit exp_av1,
        input bit exp_bv0,
        input bit exp_bv1,
        input bit exp_clear,
        input bit exp_busy,
        input bit exp_done
    );
        begin
            $display("----------------------------------------");
            $display("CHECK: %s", label);
            $display("  a_left_o   = [%0d %0d]", a_left_o[0], a_left_o[1]);
            $display("  b_top_o    = [%0d %0d]", b_top_o[0], b_top_o[1]);
            $display("  a_valid_o  = [%0b %0b]", a_valid_left_o[0], a_valid_left_o[1]);
            $display("  b_valid_o  = [%0b %0b]", b_valid_top_o[0], b_valid_top_o[1]);
            $display("  clear      = [%0b %0b; %0b %0b]",
                accumulator_clear_o[0][0], accumulator_clear_o[0][1],
                accumulator_clear_o[1][0], accumulator_clear_o[1][1]);
            $display("  busy/done  = [%0b %0b]", busy_o, done_o);

            if ((a_left_o[0] !== exp_a0) ||
                (a_left_o[1] !== exp_a1) ||
                (b_top_o[0]  !== exp_b0) ||
                (b_top_o[1]  !== exp_b1) ||
                (a_valid_left_o[0] !== exp_av0) ||
                (a_valid_left_o[1] !== exp_av1) ||
                (b_valid_top_o[0]  !== exp_bv0) ||
                (b_valid_top_o[1]  !== exp_bv1) ||
                (accumulator_clear_o[0][0] !== exp_clear) ||
                (accumulator_clear_o[0][1] !== exp_clear) ||
                (accumulator_clear_o[1][0] !== exp_clear) ||
                (accumulator_clear_o[1][1] !== exp_clear) ||
                (busy_o !== exp_busy) ||
                (done_o !== exp_done)) begin
                $display("FAIL: %s", label);
                $display("  a_left_o   = [%0d %0d], expected [%0d %0d]",
                    a_left_o[0], a_left_o[1], exp_a0, exp_a1);
                $display("  b_top_o    = [%0d %0d], expected [%0d %0d]",
                    b_top_o[0], b_top_o[1], exp_b0, exp_b1);
                $display("  a_valid_o  = [%0b %0b], expected [%0b %0b]",
                    a_valid_left_o[0], a_valid_left_o[1], exp_av0, exp_av1);
                $display("  b_valid_o  = [%0b %0b], expected [%0b %0b]",
                    b_valid_top_o[0], b_valid_top_o[1], exp_bv0, exp_bv1);
                $display("  clear/busy/done = [%0b %0b %0b], expected [%0b %0b %0b]",
                    accumulator_clear_o[0][0], busy_o, done_o,
                    exp_clear, exp_busy, exp_done);
                $finish;
            end else begin
                $display("  RESULT: PASS");
            end
        end
    endtask

    initial begin
        clk_i   = 1'b0;
        reset_i = 1'b1;
        start_i = 1'b0;

        a_matrix_i[0][0] = 1; a_matrix_i[0][1] = 2;
        a_matrix_i[1][0] = 3; a_matrix_i[1][1] = 4;

        b_matrix_i[0][0] = 5; b_matrix_i[0][1] = 6;
        b_matrix_i[1][0] = 7; b_matrix_i[1][1] = 8;

        @(posedge clk_i);
        #1;
        check_outputs("reset asserted", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

        #1;
        reset_i = 1'b0;
        check_outputs("idle after reset", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

        @(negedge clk_i);
        start_i = 1'b1;

        @(posedge clk_i);
        #1;
        check_outputs("clear cycle", 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0);

        @(negedge clk_i);
        start_i = 1'b0;

        @(posedge clk_i);
        #1;
        check_outputs("run cycle 0", 1, 0, 5, 0, 1, 0, 1, 0, 0, 1, 0);

        @(posedge clk_i);
        #1;
        check_outputs("run cycle 1", 2, 3, 7, 6, 1, 1, 1, 1, 0, 1, 0);

        @(posedge clk_i);
        #1;
        check_outputs("run cycle 2", 0, 4, 0, 8, 0, 1, 0, 1, 0, 1, 0);

        @(posedge clk_i);
        #1;
        check_outputs("run cycle 3", 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0);

        @(posedge clk_i);
        #1;
        check_outputs("done pulse", 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1);

        @(posedge clk_i);
        #1;
        check_outputs("back to idle", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

        $display("========================================");
        $display("Controller test PASSED");
        $display("========================================");
        $finish;
    end

endmodule
