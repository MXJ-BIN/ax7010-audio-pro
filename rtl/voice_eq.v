`timescale 1ns / 1ps

// Presence peak around 3 kHz, about +5 dB, Q = 0.9, fs = 48.828 kHz.
// Coefficients are Q14. a1/a2 are the normalized feedback terms.
module voice_eq (
    input  wire               clk,
    input  wire               rst,
    input  wire               en,
    input  wire signed [23:0] din,
    output reg  signed [23:0] dout
);
    localparam signed [15:0] B0 = 16'sd18113;
    localparam signed [15:0] B1 = -16'sd26240;
    localparam signed [15:0] B2 = 16'sd10212;
    localparam signed [15:0] A1 = -16'sd26240;
    localparam signed [15:0] A2 = 16'sd11941;

    reg signed [23:0] x1;
    reg signed [23:0] x2;
    reg signed [23:0] y1;
    reg signed [23:0] y2;

    function automatic signed [23:0] clip24;
        input signed [47:0] v;
        begin
            if (v > 48'sd8388607)
                clip24 = 24'sd8388607;
            else if (v < -48'sd8388608)
                clip24 = -24'sd8388608;
            else
                clip24 = v[23:0];
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            x1   <= 24'sd0;
            x2   <= 24'sd0;
            y1   <= 24'sd0;
            y2   <= 24'sd0;
            dout <= 24'sd0;
        end else if (en) begin
            begin : calc
                reg signed [47:0] acc;
                reg signed [23:0] y;
                acc  = B0 * din;
                acc  = acc + B1 * x1;
                acc  = acc + B2 * x2;
                acc  = acc - A1 * y1;
                acc  = acc - A2 * y2;
                y    = clip24(acc >>> 14);
                dout <= y;
                x2   <= x1;
                x1   <= din;
                y2   <= y1;
                y1   <= y;
            end
        end
    end
endmodule
