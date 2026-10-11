`timescale 1ns/1ps
module tb_beamformer;
 reg clk=0,rst=1,en=0;always #10 clk=~clk;
 reg signed [23:0] a,b,c,d;wire signed [23:0] out;
 beamformer dut(clk,rst,en,a,b,c,d,9'sd48,9'sd32,out);
 reg signed [23:0] data[0:255];integer i,k;
 reg signed [23:0] ramp;wire signed [23:0] fractional;
 beamformer fractional_dut(clk,rst,en,ramp,ramp,ramp,ramp,9'sd8,9'sd0,fractional);
 initial begin
 for(k=0;k<256;k=k+1)data[k]=(k*7919)%100000-50000;
 a=0;b=0;c=0;d=0;ramp=0;repeat(5)@(negedge clk);rst=0;
 for(i=8;i<200;i=i+1)begin
  @(negedge clk);en=1;ramp=i*160;a=data[i-2];b=data[i-5];c=data[i-7];d=data[i-4];
  @(negedge clk);en=0;
  if(i>=110 && out!==data[i-34])$fatal(1,"aligned sum mismatch i=%0d out=%0d expected=%0d",i,out,data[i-34]);
  if(i>=110 && fractional!==i*160-5080)$fatal(1,"fractional tap mismatch %d %d",i,fractional);
  repeat(3)@(negedge clk);
 end
 $display("TEST PASSED beamformer");$finish;
 end
endmodule
