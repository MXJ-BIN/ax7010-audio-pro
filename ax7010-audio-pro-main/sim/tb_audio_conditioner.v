`timescale 1ns/1ps
module tb_audio_conditioner;
 reg clk=0,rst=1,en=0,gate=0,agc=0,mute=0,clear=0;always #10 clk=~clk;
 reg [15:0] threshold=256;reg [7:0] volume=128;reg signed [23:0] sample=0;
 wire signed [23:0] l,r;wire open,clip;wire [11:0] gain;wire [7:0] level;
 audio_conditioner dut(clk,rst,en,gate,agc,mute,clear,threshold,volume,sample,sample,l,r,open,clip,gain,level);
 wire signed [23:0] calibrated;wire mic_clip;
 reg [7:0] mic_gain_value=64;mic_gain calibration(clk,rst,en,sample,mic_gain_value,calibrated,mic_clip);
 task feed(input integer v);begin @(negedge clk);sample=v;en=1;@(negedge clk);en=0;repeat(2)@(negedge clk);end endtask
 integer i;
 initial begin
 repeat(5)@(negedge clk);rst=0;
 for(i=0;i<20;i=i+1)feed(1048576);
 if(l!=1048576 || r!=l || calibrated!=sample)$fatal(1,"unity gain failed %d",l);
 mic_gain_value=128;feed(6000000);if(calibrated!=8388607 || !mic_clip)$fatal(1,"mic saturation failed");mic_gain_value=64;
 mute=1;feed(1048576);if(l!=0 || r!=0)$fatal(1,"mute failed");mute=0;
 gate=1;threshold=65535;for(i=0;i<300;i=i+1)feed(1048576);
 if(open || l!=0)$fatal(1,"noise gate did not close");
 threshold=256;for(i=0;i<300;i=i+1)feed(1048576);if(!open || l!=1048576)$fatal(1,"noise gate did not open");
 gate=0;agc=1;for(i=0;i<8192;i=i+1)feed(4194304);
 if(gain<=32 || gain>=200 || l<900000 || l>2200000)$fatal(1,"AGC feedback failed gain=%d out=%d",gain,l);
 agc=0;volume=64;for(i=0;i<10;i=i+1)feed(-1048576);if(l!=-524288)$fatal(1,"signed volume failed %d",l);
 $display("TEST PASSED audio_conditioner gain, saturation, gate, mute, AGC feedback");$finish;
 end
endmodule
