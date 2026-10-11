`timescale 1ns/1ps
module direction_track(input wire clk,rst,update,valid,smooth,input wire [2:0] shift,
 input wire signed [8:0] x,y,output reg signed [8:0] track_x,track_y,output wire accepted);
 wire signed [17:0] xx=$signed(x)*$signed(x),yy=$signed(y)*$signed(y);
 wire [18:0] norm2={1'b0,xx}+{1'b0,yy};
 assign accepted=valid && norm2>=3249 && norm2<=21904;
 reg [1:0] filled;reg signed [8:0] x1,x2,y1,y2;reg signed [15:0] ax,ay;
 reg [5:0] lost;
 function automatic signed [8:0] median(input signed [8:0] a,b,c);
 begin if(a>b)median=(b>c)?b:((a>c)?c:a);else median=(a>c)?a:((b>c)?c:b);end endfunction
 always @(posedge clk)begin
 if(rst)begin track_x<=0;track_y<=0;filled<=0;lost<=0;ax<=0;ay<=0;x1<=0;x2<=0;y1<=0;y2<=0;end
 else if(update)begin : filter
 reg signed [8:0] mx,my;reg signed [16:0] dx,dy,nx,ny;reg [2:0] s;
 if(accepted)begin
 lost<=0;x2<=x1;x1<=x;y2<=y1;y1<=y;
 if(filled<2)filled<=filled+1'b1;
 mx=(filled==2)?median(x,x1,x2):x;my=(filled==2)?median(y,y1,y2):y;
 s=(shift==0)?1:shift;
 if(!smooth || filled==0)begin ax<=$signed(x)*64;ay<=$signed(y)*64;track_x<=x;track_y<=y;end
 else begin
 dx=$signed(mx)*64-$signed(ax);dy=$signed(my)*64-$signed(ay);
 nx=$signed(ax)+(dx>>>s);ny=$signed(ay)+(dy>>>s);
 ax<=nx;ay<=ny;track_x<=nx>>>6;track_y<=ny>>>6;
 end
 end else begin
 if(lost<31)lost<=lost+1'b1;
 if(lost>=30)filled<=0;
 end
 end
 end
endmodule
