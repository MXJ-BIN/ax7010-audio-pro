`timescale 1ns/1ps
module tb_speech_band;
 reg clk=0,rst=1,en=0,clear=0;always #10 clk=~clk;
 reg [1:0] mode=0;reg signed [23:0] d0=0,d1=0,d2=0,d3=0;
 wire signed [23:0] o0,o1,o2,o3;wire valid,clip,overrun;
 speech_band dut(clk,rst,en,clear,mode,d0,d1,d2,d3,o0,o1,o2,o3,valid,clip,overrun);
 `include "vectors_count.vh"
 reg [193:0] vectors[0:VECTOR_COUNT-1];integer i,cycles,fd,maxcycles=0;
 initial begin
  $readmemh("vectors.hex",vectors);
  fd=$fopen("actual.txt","w");
  repeat(5)@(negedge clk);rst=0;
  for(i=0;i<VECTOR_COUNT;i=i+1)begin
   @(negedge clk);{mode,d0,d1,d2,d3}=vectors[i][193:96];en=1;
   @(negedge clk);en=0;cycles=0;
   while(!valid && cycles<220)begin @(negedge clk);cycles=cycles+1;end
   if(!valid)$fatal(1,"filter timeout vector %d",i);
   if({o0,o1,o2,o3}!==vectors[i][95:0])$fatal(1,"bit mismatch vector %d got %h expected %h",i,{o0,o1,o2,o3},vectors[i][95:0]);
   if(overrun)$fatal(1,"overrun at vector %d",i);
   if(cycles>maxcycles)maxcycles=cycles;
   $fwrite(fd,"%d %d %d\n",mode,d0,o0);
   repeat(256-cycles-2)@(negedge clk);
  end
  if(!clip)$fatal(1,"saturation stimulus did not raise clip flag");
  $fclose(fd);
  // Deliberately violate sample period to test deadline monitoring.
  rst=1;repeat(5)@(negedge clk);rst=0;mode=2;d0=1000;d1=1000;d2=1000;d3=1000;
  en=1;@(negedge clk);en=0;repeat(5)@(negedge clk);en=1;@(negedge clk);en=0;
  repeat(250)@(negedge clk);if(!overrun)$fatal(1,"missed deliberate overrun");
  clear=1;@(negedge clk);clear=0;@(negedge clk);if(overrun||clip)$fatal(1,"clear failed");
  $display("TEST PASSED speech_band: %d vectors, four channel exact DF1, all profiles, bypass, saturation, deadline, max cycles=%d",VECTOR_COUNT,maxcycles);$finish;
 end
 initial begin #1000000000;$fatal(1,"speech filter simulation timeout");end
endmodule
