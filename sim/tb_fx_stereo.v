`timescale 1ns/1ps
module tb_fx_stereo;
 reg clk=0,rst=1,en=0;always #10 clk=~clk;
 reg signed [23:0] in=0;wire signed [23:0] l,r;
 fx_stereo dut(clk,rst,en,1'b1,1'b0,in,in,l,r);
 wire signed [23:0] bypass_l,bypass_r;
 fx_stereo bypass(clk,rst,en,1'b0,1'b1,in,in,bypass_l,bypass_r);
 integer n;real input_power=0,output_power=0,ratio;
 task sample(input integer value);
 begin @(negedge clk);in=value;en=1;@(negedge clk);en=0;repeat(3)@(negedge clk);end
 endtask
 initial begin
 repeat(5)@(negedge clk);rst=0;
 for(n=0;n<4096;n=n+1)begin
 sample($rtoi(1000000.0*$sin(6.283185307179586*3000*n/48828.125)));
 if(n>2048)begin input_power=input_power+$itor(in)*$itor(in);output_power=output_power+$itor(l)*$itor(l);end
 if(l!==r)$fatal(1,"stereo mismatch");
 end
 ratio=$sqrt(output_power/input_power);
 if(ratio<1.70 || ratio>1.86)$fatal(1,"EQ dry path ratio %f",ratio);
 for(n=0;n<1024;n=n+1)sample(6000000);
 if(l<5900000 || l>6100000)$fatal(1,"large mono sign/gain %d",l);
 // Reverb input must follow EQ bypass, and averaging must not overflow.
 if(bypass.mono<5900000 || bypass.mono>6100000)$fatal(1,"bypass mono sign/gain %d",bypass.mono);
 $display("TEST PASSED fx_stereo ratio=%f",ratio);$finish;
 end
endmodule
