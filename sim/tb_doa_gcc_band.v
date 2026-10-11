`timescale 1ns/1ps
// Production DC blocker + switchable speech band -> GCC at band_valid.
module tb_doa_gcc_band;
 reg clk=0,rst=1,en=0;always #10 clk=~clk;
 reg [1:0] mode=1;reg signed [23:0] a=0,b=0,c=0,d=0;
 wire signed [23:0] h0,h1,h2,h3,v0,v1,v2,v3;wire bv,clip,bo;
 dc_block dc0(clk,rst,en,a,h0);dc_block dc1(clk,rst,en,b,h1);
 dc_block dc2(clk,rst,en,c,h2);dc_block dc3(clk,rst,en,d,h3);
 speech_band band(clk,rst,en,1'b0,mode,h0,h1,h2,h3,v0,v1,v2,v3,bv,clip,bo);
 wire signed [8:0] x,y;wire valid,update,overrun;wire [4:0] q;wire [7:0] seq;
 doa_square dut(clk,rst,bv,v0[23:8],v1[23:8],v2[23:8],v3[23:8],x,y,valid,update,q,seq,overrun);
 reg signed [15:0] data[0:4095];reg [31:0] seed=32'h82407623;integer k,i,m,count=0;
 always @(negedge clk)if(update)begin
 $display("BAND mode=%0d seq=%0d x=%0d y=%0d valid=%0d",mode,seq,x,y,valid);
 if(seq>=2 && (!valid || x<45 || x>51 || y<93 || y>99))$fatal(1,"filtered voice rejected or delay inaccurate");
 if(clip || bo || overrun)$fatal(1,"band pipeline diagnostic");count=count+1;
 end
 initial begin
 for(k=0;k<4096;k=k+1)begin seed={seed[30:0],seed[31]^seed[21]^seed[1]^seed[0]};data[k]=$signed(seed[15:0])>>>2;end
 for(m=0;m<4;m=m+1)begin
 @(negedge clk);rst=1;en=0;mode=m;repeat(5)@(negedge clk);rst=0;count=0;
 for(k=0;k<2048;k=k+1)begin i=k+64;
 @(negedge clk);en=1;a=$signed(data[i])*256;b=$signed(data[i-3])*256;
 c=$signed(data[i-9])*256;d=$signed(data[i-6])*256;
 @(negedge clk);en=0;repeat(1022)@(negedge clk);
 end
 wait(count==4);
 end
 $display("TEST PASSED doa_gcc_band");$finish;
 end
 initial begin #220000000;$fatal(1,"band timeout");end
endmodule
