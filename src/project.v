`default_nettype none
module tt_um_tinymppt (
    input  wire [7:0] ui_in,
    input  wire [7:0] uio_in,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n,
    output wire [7:0] uo_out,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe
);

    // --- Pin mapping ---
    wire       pulse_in   = ui_in[0];
    wire       manual_en  = ui_in[1];
    wire [3:0] manual_cfg = uio_in[3:0];

    // --- Internal registers ---
    reg [13:0] window_cnt;
    reg [15:0] pulse_cnt;
    reg [15:0] prev_power;
    reg [15:0] curr_power;
    reg [3:0]  cfg;
    reg [3:0]  cfg_last;   // config during the window just measured
    reg        direction;
    reg        pulse_in_d;

    localparam WINDOW_MAX = 14'd16383;  // ~1.6 ms at 10 MHz

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            window_cnt <= 14'd0;
            pulse_cnt  <= 16'd0;
            prev_power <= 16'd0;
            curr_power <= 16'd0;
            cfg        <= 4'd8;
            cfg_last   <= 4'd8;
            direction  <= 1'b1;
            pulse_in_d <= 1'b0;
        end else if (ena) begin
            // count pulses (rising-edge detect)
            pulse_in_d <= pulse_in;
            if (pulse_in && !pulse_in_d && !manual_en)
                pulse_cnt <= pulse_cnt + 16'd1;

            if (window_cnt == WINDOW_MAX) begin
                window_cnt <= 14'd0;
                prev_power <= curr_power;
                curr_power <= pulse_cnt;   // window just finished
                cfg_last   <= cfg;         // setting used during it
                pulse_cnt  <= 16'd0;

                if (!manual_en) begin
                    // compare finished window vs previous window:
                    // two DIFFERENT settings -> a real step was tested
                    if (pulse_cnt >= curr_power) begin
                        // last step helped (or tie): keep walking
                        if (direction) cfg <= (cfg == 4'd15) ? 4'd15 : cfg + 4'd1;
                        else           cfg <= (cfg == 4'd0)  ? 4'd0  : cfg - 4'd1;
                    end else begin
                        // last step hurt: turn around
                        direction <= ~direction;
                        if (~direction) cfg <= (cfg == 4'd15) ? 4'd15 : cfg + 4'd1;
                        else            cfg <= (cfg == 4'd0)  ? 4'd0  : cfg - 4'd1;
                    end
                end
            end else begin
                window_cnt <= window_cnt + 14'd1;
            end

            if (manual_en)
                cfg <= manual_cfg;
        end
    end

    // --- Outputs ---
    assign uo_out[3:0] = cfg;
    assign uo_out[4]   = (window_cnt == 14'd0);
    assign uo_out[5]   = direction;
    assign uo_out[6]   = manual_en;
    assign uo_out[7]   = 1'b0;
    assign uio_out     = 8'b0;
    assign uio_oe      = 8'b0;

endmodule
