`timescale 1ns / 1ps

// One-pole high-pass, about 120 Hz at 48.828 kHz.
// y[n] = x[n] - x[n-1] + y[n-1] * 63/64.
module dc_block (
    input  wire               clk,
    input  wire               rst,
    input  wire               en,
    input  wire signed [23:0] din,
    output reg  signed [23:0] dout
);
    reg signed [23:0] x1;
    reg signed [23:0] y1;

    function automatic signed [23:0] clip24;
        input signed [27:0] v;
        begin
            if (v > 28'sd8388607)
                clip24 = 24'sd8388607;
            else if (v < -28'sd8388608)
                clip24 = -24'sd8388608;
            else
                clip24 = v[23:0];
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            x1   <= 24'sd0;
            y1   <= 24'sd0;
            dout <= 24'sd0;
        end else if (en) begin
            begin : calc
                reg signed [27:0] acc;
                reg signed [23:0] y;
                acc  = din - x1 + y1 - (y1 >>> 6);
                y    = clip24(acc);
                dout <= y;
                x1   <= din;
                y1   <= y;
            end
        end
    end
endmodule
