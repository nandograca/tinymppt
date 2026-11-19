`timescale 1ns/1ps
module test_tb;
    reg  clk = 0;
    reg  rst_n = 0;
    wire [7:0] ui_in;
    wire [7:0] uio_in = 8'b0;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    always #50 clk = ~clk;              // 10 MHz clock

    // ---- Fake harvester: pulse rate depends on cfg, hill peaks at cfg = 12
    reg pulse = 0;
    reg [15:0] pdiv = 0;

    function [15:0] period_for;
        input [3:0] c;
        integer d;
        begin
            d = (c > 4'd12) ? (c - 4'd12) : (4'd12 - c);
            period_for = 16'd100 + d * 16'd100;
        end
    endfunction

    always @(negedge clk) begin
        if (!rst_n) begin
            pulse <= 1'b0;
            pdiv  <= 16'd0;
        end else if (pdiv == 16'd0) begin
            pulse <= ~pulse;
            pdiv  <= period_for(uo_out[3:0]);
        end else begin
            pdiv <= pdiv - 16'd1;
        end
    end

    assign ui_in = {6'b0, 1'b0, pulse};   // [1]=auto mode, [0]=pulses

    tt_um_tinymppt dut (
        .ui_in(ui_in), .uio_in(uio_in), .ena(1'b1),
        .clk(clk), .rst_n(rst_n),
        .uo_out(uo_out), .uio_out(uio_out), .uio_oe(uio_oe)
    );

    // one line per measurement window: setting used + power it produced
    always @(posedge clk) begin
        if (rst_n && dut.window_cnt == 14'd0)
            $display("window: cfg=%0d  power=%0d  dir=%0d",
                      dut.cfg_last, dut.curr_power, dut.direction);
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, test_tb);
        rst_n = 0;
        #1000;
        rst_n = 1;
        #25000000;                       // 25 ms of chip time
        $display("FINAL CONFIG = %0d  (hill peak is 12)", uo_out[3:0]);
        $finish;
    end
endmodule

