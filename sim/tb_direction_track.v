`timescale 1ns/1ps
module tb_direction_track;
 reg clk=0,rst=1,update=0,valid=1,smooth=1;always #10 clk=~clk;
 reg signed [8:0] x=0,y=0;wire signed [8:0] tx,ty;wire accepted;
 direction_track dut(clk,rst,update,valid,smooth,3'd2,x,y,tx,ty,accepted);
 task feed(input integer a,b);begin @(negedge clk);x=a;y=b;update=1;@(negedge clk);update=0;repeat(2)@(negedge clk);end endtask
 integer i;
 initial begin
 repeat(5)@(negedge clk);rst=0;
 feed(0,0);if(accepted || tx!=0)$fatal(1,"zero geometry accepted");
 feed(114,0);feed(114,0);feed(114,0);feed(0,114);
 if(tx<110 || ty>4)$fatal(1,"median failed to reject spike %d %d",tx,ty);
 for(i=0;i<24;i=i+1)feed(-114,0);
 if(tx> -110)$fatal(1,"tracking failed to converge %d",tx);
 feed(200,200);if(accepted || tx> -110)$fatal(1,"unphysical geometry accepted");
 smooth=0;feed(0,-114);if(tx!=0 || ty!=-114)$fatal(1,"bypass failed");
 $display("TEST PASSED direction_track geometry, median, signed convergence");$finish;
 end
endmodule
