`timescale 1ns/1ps
// 32-sample common latency, Q4 linear fractional delay, four-channel mean.
module beamformer(input wire clk,rst,en,input wire signed [23:0] m0,m1,m2,m3,
 input wire signed [8:0] lag_x,lag_y, output reg signed [23:0] sample);
 reg signed [23:0] r0[0:127],r1[0:127],r2[0:127],r3[0:127];
 reg [6:0] wr; reg [7:0] fill;
 function automatic signed [23:0] tap;
 input signed [23:0] a,b;input [3:0] frac;
 reg signed [31:0] t;
 begin t=a*$signed({1'b0,(5'd16-{1'b0,frac})})+b*$signed({1'b0,frac});tap=t>>>4;end
 endfunction
 always @(posedge clk)begin
  if(rst)begin wr<=0;fill<=0;sample<=0;end
  else if(en)begin : calc
   reg signed [10:0] d1,d2,d3;
   reg [6:0] p0,p1,p2,p3;
   reg signed [25:0] sum;
   r0[wr]<=m0;r1[wr]<=m1;r2[wr]<=m2;r3[wr]<=m3;
   d1=11'sd512-$signed(lag_x);d2=11'sd512-$signed(lag_x)-$signed(lag_y);d3=11'sd512-$signed(lag_y);
   p0=wr-7'd32;p1=wr-d1[10:4];p2=wr-d2[10:4];p3=wr-d3[10:4];
   if(fill>=96)begin
    sum=r0[p0];sum=sum+tap(r1[p1],r1[(p1-7'd1)&7'h7f],d1[3:0]);
    sum=sum+tap(r2[p2],r2[(p2-7'd1)&7'h7f],d2[3:0]);sum=sum+tap(r3[p3],r3[(p3-7'd1)&7'h7f],d3[3:0]);
    sample<=sum>>>2;
   end else begin fill<=fill+1'b1;sample<=0;end
   wr<=wr+1'b1;
  end
 end
endmodule
