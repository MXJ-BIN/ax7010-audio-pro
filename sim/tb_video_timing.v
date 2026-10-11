`timescale 1ns/1ps
module tb_video_timing;
reg clk=0,rst=1;always #5 clk=~clk;
wire hs,vs,de;wire [10:0] x;wire [9:0] y;wire [23:0] rgb;
video_timing_720p dut(clk,rst,hs,vs,de,x,y,rgb);
integer i,phase,linepixels=0,hswidth=0,active_lines=0,total_active=0,vswidth=0,hsedges=0,vsedges=0;
reg oldvs=0,oldhs=0;
initial begin
 repeat(3)@(negedge clk);rst=0;
 for(i=0;i<2475000;i=i+1)begin
  #1;phase=i%1650;
  if((^({hs,vs,de,x,y}))===1'bx)$fatal(1,"unknown timing");
  if(i%1237500==0)begin active_lines=0;end
  if(vs!=oldvs && phase!=0)$fatal(1,"Vsync edge not aligned with Hsync origin");
  if(vs&&!oldvs)begin if(!hs)$fatal(1,"Vsync rising outside Hsync rising");vsedges=vsedges+1;end
  if(hs&&!oldhs)hsedges=hsedges+1;
  if(vs)vswidth=vswidth+1;
  if(hs)hswidth=hswidth+1;
  if(de)begin
   if(hs||vs)$fatal(1,"active video overlaps sync");
   if(x!==linepixels || y!==active_lines)$fatal(1,"coordinate discontinuity %d,%d",x,y);
   linepixels=linepixels+1;total_active=total_active+1;
  end
  if(phase==1649)begin
   if(hswidth!=40)$fatal(1,"incorrect Hsync width");hswidth=0;
   if(linepixels!=0 && linepixels!=1280)$fatal(1,"incorrect active line length");
   if(linepixels)active_lines=active_lines+1;
   linepixels=0;
   if(i%1237500==1237499 && active_lines!=720)$fatal(1,"incorrect active height");
  end
  oldhs=hs;oldvs=vs;
  @(negedge clk);
 end
 if(total_active!=1843200 || vswidth!=16500 || hsedges!=1500 || vsedges!=2)$fatal(1,"incorrect frame dimensions/pulses");
 $display("TEST PASSED 720p: two frames, 1280x720 active, 1650x750 total, HS/VS alignment");$finish;
end
endmodule
