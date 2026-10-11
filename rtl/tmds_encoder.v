`timescale 1ns / 1ps

module tmds_encoder (
    input  wire       pixel_clk,
    input  wire       reset,
    input  wire [7:0] video_data,
    input  wire [1:0] control_data,
    input  wire       video_enable,
    output reg  [9:0] tmds_data
);
    integer i;
    reg [3:0] ones_data;
    reg [3:0] ones_qm;
    reg [8:0] q_m;
    reg signed [5:0] disparity;
    reg signed [5:0] balance;
    reg use_xnor;

    always @(*) begin
        ones_data = video_data[0] + video_data[1] + video_data[2] +
                    video_data[3] + video_data[4] + video_data[5] +
                    video_data[6] + video_data[7];
        use_xnor = (ones_data > 4) ||
                   ((ones_data == 4) && (video_data[0] == 1'b0));
        q_m[0] = video_data[0];
        for (i = 1; i < 8; i = i + 1) begin
            if (use_xnor)
                q_m[i] = ~(q_m[i-1] ^ video_data[i]);
            else
                q_m[i] = q_m[i-1] ^ video_data[i];
        end
        q_m[8] = ~use_xnor;
        ones_qm = q_m[0] + q_m[1] + q_m[2] + q_m[3] +
                  q_m[4] + q_m[5] + q_m[6] + q_m[7];
        balance = $signed({1'b0, ones_qm, 1'b0}) - 6'sd8;
    end

    always @(posedge pixel_clk) begin
        if (reset) begin
            disparity <= 0;
            tmds_data <= 10'b1101010100;
        end else if (!video_enable) begin
            disparity <= 0;
            case (control_data)
                2'b00: tmds_data <= 10'b1101010100;
                2'b01: tmds_data <= 10'b0010101011;
                2'b10: tmds_data <= 10'b0101010100;
                default: tmds_data <= 10'b1010101011;
            endcase
        end else if ((disparity == 0) || (balance == 0)) begin
            tmds_data[9] <= ~q_m[8];
            tmds_data[8] <= q_m[8];
            tmds_data[7:0] <= q_m[8] ? q_m[7:0] : ~q_m[7:0];
            disparity <= q_m[8] ? balance : -balance;
        end else if (((disparity > 0) && (balance > 0)) ||
                     ((disparity < 0) && (balance < 0))) begin
            tmds_data[9] <= 1'b1;
            tmds_data[8] <= q_m[8];
            tmds_data[7:0] <= ~q_m[7:0];
            disparity <= disparity - balance + (q_m[8] ? 6'sd2 : 6'sd0);
        end else begin
            tmds_data[9] <= 1'b0;
            tmds_data[8] <= q_m[8];
            tmds_data[7:0] <= q_m[7:0];
            disparity <= disparity + balance - (q_m[8] ? 6'sd0 : 6'sd2);
        end
    end
endmodule
