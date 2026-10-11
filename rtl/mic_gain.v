`timescale 1ns/1ps
module mic_gain(input wire clk,rst,en,input wire signed [23:0] sample,input wire [7:0] gain,
 output reg signed [23:0] value,output reg clipped);
 wire signed [32:0] product=$signed(sample)*$signed({1'b0,gain});
 wire signed [32:0] scaled=product>>>6;
 always @(posedge clk)begin
 if(rst)begin value<=0;clipped<=0;end
 else if(en)begin
 clipped<=scaled>8388607 || scaled< -8388608;
 if(scaled>8388607)value<=8388607;else if(scaled< -8388608)value<=-8388608;else value<=scaled[23:0];
 end end
endmodule
