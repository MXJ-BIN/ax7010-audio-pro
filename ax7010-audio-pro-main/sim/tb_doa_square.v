`timescale 1ns/1ps
module tb_doa_square;
 reg clk=0,rst=1,en=0;always #10 clk=~clk;
 reg signed [15:0] m0=0,m1=0,m2=0,m3=0;
 wire signed [8:0] x,y;wire valid,update,overrun;wire [4:0] quality;wire [7:0] seq;
 doa_square #(.GCC_PHAT(0),.FRAME(64),.MAX_LAG(8),.ENERGY_MIN(100000)) dut(clk,rst,en,m0,m1,m2,m3,x,y,valid,update,quality,seq,overrun);
 reg signed [15:0] data[0:255];integer i,k;
 reg [31:0] lfsr=32'h76543210;
 task feed(input integer a,b,c,d,input integer silent);
 begin
 for(i=16;i<80;i=i+1)begin
  @(negedge clk);en=1;
  m0=silent?0:data[i-a];m1=silent?0:data[i-b];m2=silent?0:data[i-c];m3=silent?0:data[i-d];
  @(negedge clk);en=0;repeat(127)@(negedge clk);
 end
 end endtask
 task check(input integer ex,ey,ev);
 begin wait(update);#1;
 if(valid!==ev || (ev && ((x<ex-3)||(x>ex+3)||(y<ey-3)||(y>ey+3))))
  $fatal(1,"DOA expected %d,%d valid %d got %d,%d valid %b",ex,ey,ev,x,y,valid);
 if(overrun)$fatal(1,"overrun");
 $display("PASS doa x=%0d y=%0d valid=%0d",x,y,valid);
 end endtask
 initial begin
 for(k=0;k<256;k=k+1)begin lfsr={lfsr[30:0],lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};data[k]=$signed(lfsr[15:0])>>>2;end
 repeat(5)@(negedge clk);rst=0;
 feed(2,5,7,4,0);check(48,32,1);
 feed(7,4,2,5,0);check(-48,-32,1);
 for(i=16;i<80;i=i+1)begin
  @(negedge clk);en=1;
  m0=data[i];m1=($signed(data[i-3])+$signed(data[i-4]))/2;
  m2=data[i-6];m3=($signed(data[i-2])+$signed(data[i-3]))/2;
  @(negedge clk);en=0;repeat(127)@(negedge clk);
 end
 check(56,40,1);
 feed(2,2,2,2,1);check(0,0,0);
 $display("TEST PASSED doa_square");$finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
