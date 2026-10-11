`timescale 1ns/1ps
module tb_i2s_four;
 reg clk=0,rst=1;always #10 clk=~clk;
 reg [3:0] sd=0;wire bclk,lrck,dac,en;wire [23:0] r0,r1,r2,r3;
 i2s_duplex dut(clk,rst,24'h123456,24'hfedcba,sd[0],sd[1],sd[2],sd[3],bclk,lrck,dac,r0,r1,r2,r3,en);
 integer slot=0,frames=0;reg old=0;
 reg [23:0] samples[0:3];integer j;
 initial begin samples[0]=24'h123456;samples[1]=24'hfedcba;samples[2]=24'h800001;samples[3]=24'h7fffff;
 repeat(5)@(negedge clk);rst=0;end
 always @(negedge bclk)begin
 if(lrck!=old)slot=0;else slot=slot+1;old=lrck;
 for(j=0;j<4;j=j+1)sd[j]=(!lrck && slot>=1 && slot<=24)?samples[j][24-slot]:0;
 end
 always @(posedge clk)if(en)begin
 if(frames>0 && {r3,r2,r1,r0}!={samples[3],samples[2],samples[1],samples[0]})$fatal(1,"four-channel decode");
 frames=frames+1;
 if(frames==5)begin $display("TEST PASSED i2s_four");$finish;end
 end
 initial begin #200000;$fatal(1,"timeout");end
endmodule
