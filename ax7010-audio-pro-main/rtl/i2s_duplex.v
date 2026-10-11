`timescale 1ns / 1ps

// I2S master for four INMP441 data lines and one PCM5102A.
// PL clock is 50 MHz. BCLK is 50e6/16 = 3.125 MHz, LRCK is BCLK/64,
// so the sample rate is 48828.125 Hz. All mics share BCLK/LRCK and
// drive only the left slot (tie each module's L/R pin to GND).
// Philips I2S: LRCK changes on a BCLK falling edge, MSB is the next bit.
module i2s_duplex (
    input  wire        clk,
    input  wire        rst,
    input  wire [23:0] tx_left,
    input  wire [23:0] tx_right,
    input  wire        sd_mic0,
    input  wire        sd_mic1,
    input wire sd_mic2, sd_mic3,
    output wire        bclk,
    output wire        lrck,
    output reg         sd_dac,
    output reg  [23:0] rx_mic0,
    output reg  [23:0] rx_mic1,
    output reg [23:0] rx_mic2, rx_mic3,
    output reg         sample_valid
);
    reg [9:0] div;
    reg [23:0] sh0;
    reg [23:0] sh1, sh2, sh3;
    reg [23:0] hold_l;
    reg [23:0] hold_r;

    assign bclk = div[3];
    assign lrck = div[9];

    function automatic sd_bit;
        input [5:0] slot;
        input [23:0] left;
        input [23:0] right;
        reg [23:0] word;
        reg [4:0] idx;
        begin
            idx  = slot[4:0];
            word = slot[5] ? right : left;
            if (idx >= 5'd1 && idx <= 5'd24)
                sd_bit = word[5'd24 - idx];
            else
                sd_bit = 1'b0;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            div          <= 10'd0;
            sd_dac       <= 1'b0;
            sh0          <= 24'd0;
            sh1 <= 0; sh2 <= 0; sh3 <= 0;
            hold_l       <= 24'd0;
            hold_r       <= 24'd0;
            rx_mic0      <= 24'd0;
            rx_mic1 <= 0; rx_mic2 <= 0; rx_mic3 <= 0;
            sample_valid <= 1'b0;
        end else begin
            sample_valid <= 1'b0;

            // BCLK falling edge. Present the bit that the next rising edge samples.
            if (div[3:0] == 4'd15) begin
                sd_dac <= sd_bit(div[9:4] + 6'd1, hold_l, hold_r);
                if (div[9:4] == 6'd63) begin
                    hold_l <= tx_left;
                    hold_r <= tx_right;
                end
            end

            // BCLK rising edge. Left-slot bits 1..24 are the 24-bit sample.
            if (div[3:0] == 4'd7) begin
                if (div[8:4] >= 5'd1 && div[8:4] <= 5'd24) begin
                    sh0 <= {sh0[22:0], sd_mic0};
                    sh1 <= {sh1[22:0], sd_mic1};
                    sh2 <= {sh2[22:0], sd_mic2}; sh3 <= {sh3[22:0], sd_mic3};
                end
                if (div[9:4] == 6'd24) begin
                    rx_mic0      <= {sh0[22:0], sd_mic0};
                    rx_mic1 <= {sh1[22:0], sd_mic1};
                    rx_mic2 <= {sh2[22:0], sd_mic2}; rx_mic3 <= {sh3[22:0], sd_mic3};
                    sample_valid <= 1'b1;
                end
            end

            div <= div + 10'd1;
        end
    end
endmodule
