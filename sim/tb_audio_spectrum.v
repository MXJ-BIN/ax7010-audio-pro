`timescale 1ns/1ps
module tb_audio_spectrum;
 reg clk=0,rst=1,en=0;always #10 clk=~clk;reg signed [15:0] sample=0;
 wire [127:0] bars;wire [7:0] seq;wire overrun;
 audio_spectrum dut(clk,rst,en,sample,bars,seq,overrun);
 integer i,k;reg [7:0] old_seq;
 task feed(input integer tone);
 begin old_seq=seq;
 for(i=0;i<512;i=i+1)begin
 @(negedge clk);en=1;sample=tone?$rtoi(16000.0*$sin(6.283185307179586*16*i/512)):((i==0)?16384:0);
 @(negedge clk);en=0;repeat(62)@(negedge clk);
 end
 wait(seq!=old_seq);#1;
 if(overrun)$fatal(1,"FFT frame overrun");
 end endtask
 initial begin
 repeat(5)@(negedge clk);rst=0;feed(0);
 for(k=0;k<16;k=k+1)if(bars[k*8+:8]!=72)$fatal(1,"impulse flat spectrum bin %d level %d",k,bars[k*8+:8]);
 feed(1);if(bars[9*8+:8]<156)$fatal(1,"tone peak too low %d",bars[9*8+:8]);
 for(k=0;k<16;k=k+1)if(k!=9 && bars[k*8+:8]>=bars[9*8+:8]-48)$fatal(1,"tone peak not isolated bin %d",k);
 $display("TEST PASSED audio_spectrum impulse and FFT bin16 tone");$finish;
 end
 initial begin #10000000;$fatal(1,"FFT timeout");end
endmodule
