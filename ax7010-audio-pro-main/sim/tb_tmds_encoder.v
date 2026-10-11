`timescale 1ns/1ps
module tb_tmds_encoder;
 reg clk=0,rst=1,de=0; reg [7:0] data=0;reg [1:0] ctl=0;
 wire [9:0] out;always #5 clk=~clk;
 tmds_encoder dut(clk,rst,data,ctl,de,out);
 integer k,j,ones,nqm,disp=0,bal,actual,seed=23;reg xn;reg [8:0] qm;reg [9:0] expected;
 initial begin
 repeat(4)@(negedge clk);rst=0;
 for(k=0;k<2048;k=k+1)begin
 data=$random(seed);de=(k%31!=0);ctl=k%4;
 ones=0;for(j=0;j<8;j=j+1)ones=ones+data[j];
 xn=(ones>4)||((ones==4)&&!data[0]);qm[0]=data[0];
 for(j=1;j<8;j=j+1)qm[j]=xn?~(qm[j-1]^data[j]):(qm[j-1]^data[j]);
 qm[8]=!xn;nqm=0;for(j=0;j<8;j=j+1)nqm=nqm+qm[j];bal=2*nqm-8;
 if(!de)begin
 disp=0;case(ctl)0:expected=10'b1101010100;1:expected=10'b0010101011;2:expected=10'b0101010100;3:expected=10'b1010101011;endcase
 end else if(disp==0||bal==0)begin
 expected={!qm[8],qm[8],qm[8]?qm[7:0]:~qm[7:0]};disp=qm[8]?bal:-bal;
 end else if((disp>0&&bal>0)||(disp<0&&bal<0))begin
 expected={1'b1,qm[8],~qm[7:0]};disp=disp-bal+(qm[8]?2:0);
 end else begin expected={1'b0,qm[8],qm[7:0]};disp=disp+bal-(qm[8]?0:2);end
 @(posedge clk);#1;
 if(out!==expected)$fatal(1,"TMDS mismatch k=%d expected=%b got=%b",k,expected,out);
 @(negedge clk);
 end
 $display("TEST PASSED tmds_encoder randomized control and video");$finish;
 end
endmodule
