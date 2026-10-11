`timescale 1ns/1ps
module tb_doa_full;
 reg clk=0,rst=1,en=0;always #10 clk=~clk;
 reg signed [15:0] a=0,b=0,c=0,d=0;
 wire signed [8:0] x,y;wire valid,update,overrun;wire [4:0] q;wire [7:0] seq;
 doa_square dut(clk,rst,en,a,b,c,d,x,y,valid,update,q,seq,overrun);
 reg signed [15:0] data[0:2047];reg [31:0] lfsr=32'h76543210;integer i,k,count=0;
 always @(negedge clk)if(update)begin
 if(!valid||x<45||x>51||y<29||y>35||overrun)$fatal(1,"full frame result x=%d y=%d valid=%b overrun=%b",x,y,valid,overrun);
 count=count+1;
 end
 initial begin
 for(k=0;k<2048;k=k+1)begin lfsr={lfsr[30:0],lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};data[k]=$signed(lfsr[15:0])>>>2;end
 repeat(5)@(negedge clk);rst=0;
 for(i=16;i<16+3*512;i=i+1)begin
 @(negedge clk);en=1;a=data[i-2];b=data[i-5];c=data[i-7];d=data[i-4];
 @(negedge clk);en=0;repeat(1022)@(negedge clk);
 end
 wait(count==3);
 if(overrun)$fatal(1,"continuous capture overrun");
 $display("TEST PASSED doa_full 512 samples at 1024 clocks/sample continuous capture");$finish;
 end
 initial begin #50000000;$fatal(1,"timeout");end
endmodule
