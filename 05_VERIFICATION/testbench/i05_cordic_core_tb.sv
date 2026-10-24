module i05_cordic_core_tb;

    logic clk=0, rst_n=0, start=0;
    logic [7:0] angle;
    logic signed [7:0] sin_out, cos_out;
    logic busy, done;

    i05_cordic_core dut(
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .angle(angle),
        .sin_out(sin_out),
        .cos_out(cos_out),
        .busy(busy),
        .done(done)
    );

    always #5 clk=~clk;
initial begin
    $dumpfile("i05_cordic_core_tb.vcd");
    $dumpvars(0, i05_cordic_core_tb);
end

    task automatic run_case(
        input [7:0] p,
        input integer sin_expected,
        input integer cos_expected
    );
        integer ds, dc;
        begin
            @(negedge clk);
            angle=p;
            start=1'b1;

            @(negedge clk);
            start=1'b0;

            wait(done);

            ds = $signed(sin_out) - sin_expected;
            dc = $signed(cos_out) - cos_expected;

            assert ((ds <= 4) && (ds >= -4))
                else $fatal(1,"sin mismatch p=%0d got=%0d exp=%0d",
                            p,$signed(sin_out),sin_expected);

            assert ((dc <= 4) && (dc >= -4))
                else $fatal(1,"cos mismatch p=%0d got=%0d exp=%0d",
                            p,$signed(cos_out),cos_expected);
        end
    endtask

    initial begin
        angle=0;

        repeat(2) @(posedge clk);
        rst_n=1;

        run_case(8'd0,   0,    127);
        run_case(8'd64,  127,  0);
        run_case(8'd128, 0,   -128);
        run_case(8'd192, -128, 0);
        run_case(8'd32,  91,   91);
        run_case(8'd224, -91,  91);

        $display("I05 RTL TB PASS");
        $finish;
    end
endmodule
