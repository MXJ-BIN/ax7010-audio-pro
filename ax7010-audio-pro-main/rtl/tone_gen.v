`timescale 1ns / 1ps

// 1 kHz tone at the 48828.125 Hz sample rate produced from the 50 MHz clock.
// phase_inc = round(1000 / 48828.125 * 2^32).
module tone_gen (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_valid,
    output reg  signed [15:0] sample
);
    localparam [31:0] PHASE_INC = 32'd87960930;

    reg [31:0] phase;

    function automatic signed [15:0] sine64;
        input [5:0] idx;
        begin
            case (idx)
                6'd0: sine64 = 16'sd0;
                6'd1: sine64 = 16'sd1960;
                6'd2: sine64 = 16'sd3902;
                6'd3: sine64 = 16'sd5806;
                6'd4: sine64 = 16'sd7654;
                6'd5: sine64 = 16'sd9428;
                6'd6: sine64 = 16'sd11111;
                6'd7: sine64 = 16'sd12688;
                6'd8: sine64 = 16'sd14142;
                6'd9: sine64 = 16'sd15460;
                6'd10: sine64 = 16'sd16629;
                6'd11: sine64 = 16'sd17638;
                6'd12: sine64 = 16'sd18478;
                6'd13: sine64 = 16'sd19139;
                6'd14: sine64 = 16'sd19616;
                6'd15: sine64 = 16'sd19904;
                6'd16: sine64 = 16'sd20000;
                6'd17: sine64 = 16'sd19904;
                6'd18: sine64 = 16'sd19616;
                6'd19: sine64 = 16'sd19139;
                6'd20: sine64 = 16'sd18478;
                6'd21: sine64 = 16'sd17638;
                6'd22: sine64 = 16'sd16629;
                6'd23: sine64 = 16'sd15460;
                6'd24: sine64 = 16'sd14142;
                6'd25: sine64 = 16'sd12688;
                6'd26: sine64 = 16'sd11111;
                6'd27: sine64 = 16'sd9428;
                6'd28: sine64 = 16'sd7654;
                6'd29: sine64 = 16'sd5806;
                6'd30: sine64 = 16'sd3902;
                6'd31: sine64 = 16'sd1960;
                6'd32: sine64 = 16'sd0;
                6'd33: sine64 = -16'sd1960;
                6'd34: sine64 = -16'sd3902;
                6'd35: sine64 = -16'sd5806;
                6'd36: sine64 = -16'sd7654;
                6'd37: sine64 = -16'sd9428;
                6'd38: sine64 = -16'sd11111;
                6'd39: sine64 = -16'sd12688;
                6'd40: sine64 = -16'sd14142;
                6'd41: sine64 = -16'sd15460;
                6'd42: sine64 = -16'sd16629;
                6'd43: sine64 = -16'sd17638;
                6'd44: sine64 = -16'sd18478;
                6'd45: sine64 = -16'sd19139;
                6'd46: sine64 = -16'sd19616;
                6'd47: sine64 = -16'sd19904;
                6'd48: sine64 = -16'sd20000;
                6'd49: sine64 = -16'sd19904;
                6'd50: sine64 = -16'sd19616;
                6'd51: sine64 = -16'sd19139;
                6'd52: sine64 = -16'sd18478;
                6'd53: sine64 = -16'sd17638;
                6'd54: sine64 = -16'sd16629;
                6'd55: sine64 = -16'sd15460;
                6'd56: sine64 = -16'sd14142;
                6'd57: sine64 = -16'sd12688;
                6'd58: sine64 = -16'sd11111;
                6'd59: sine64 = -16'sd9428;
                6'd60: sine64 = -16'sd7654;
                6'd61: sine64 = -16'sd5806;
                6'd62: sine64 = -16'sd3902;
                6'd63: sine64 = -16'sd1960;
                default: sine64 = 16'sd0;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            phase  <= 32'd0;
            sample <= 16'sd0;
        end else if (sample_valid) begin
            sample <= sine64(phase[31:26]);
            phase  <= phase + PHASE_INC;
        end
    end
endmodule
