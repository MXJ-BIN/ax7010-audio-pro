`timescale 1ns/1ps
// 720p XY direction plot: right/front source corresponds to negative x/y lag.
// Ring radius 228 pixels represents 50 mm at 48.828125 kHz and 343 m/s.
module audio_dashboard(input wire pixel_clk,reset,input wire [10:0] x_in,input wire [9:0] y_in,
 input wire de_in,input wire [287:0] frame_in,output reg [23:0] rgb);
 // One aligned pixel stage: squared radius and label addressing run in parallel.
 reg [10:0] x;reg [9:0] y;reg de;reg [287:0] frame_data;
 reg [23:0] x_sq,y_sq;
 wire signed [11:0] input_dx=$signed({1'b0,x_in})-12'sd640;
 wire signed [11:0] input_dy=$signed({2'b0,y_in})-12'sd360;
 always @(posedge pixel_clk)begin
  if(reset)begin x<=0;y<=0;de<=0;frame_data<=0;x_sq<=0;y_sq<=0;end
  else begin x<=x_in;y<=y_in;de<=de_in;frame_data<=frame_in;
   x_sq<=input_dx*input_dx;y_sq<=input_dy*input_dy;end
 end
 wire signed [8:0] lx=frame_data[8:0],ly=frame_data[17:9];
 wire signed [8:0] tx=frame_data[48:40],ty=frame_data[57:49];
 wire valid=frame_data[18];
 wire text_ink;wire [23:0] text_color;
 dashboard_text text(pixel_clk,reset,de_in,x_in,y_in,frame_in,text_ink,text_color);
 integer r2,px,py,qx,qy,ch,bar,spec_index,spec_value;
 always @*begin
  ch=0;bar=0;spec_index=0;spec_value=0;
  r2=x_sq+y_sq;
  px=640-$signed(lx)*2;py=360+$signed(ly)*2;
  qx=640-$signed(tx)*2;qy=360+$signed(ty)*2;
  rgb=24'h101820;
  if(!de)rgb=0;
  else begin
   if(x<12||x>1267||y<12||y>707)rgb=24'h334452;
   if(r2>51000 && r2<52900)rgb=24'h415667;
   if((x>=638&&x<=642&&y>110&&y<610)||(y>=358&&y<=362&&x>390&&x<890))rgb=24'h334452;
   if(x>=px-6&&x<=px+6&&y>=py-6&&y<=py+6)rgb=valid?24'h32dda5:24'h607080;
   if(x>=qx-9&&x<=qx+9&&y>=qy-9&&y<=qy+9 && (x<qx-6||x>qx+6||y<qy-6||y>qy+6))rgb=24'hf1b84b;
   if(x>=64&&x<320&&y>=100&&y<340)begin
    if(y<160)ch=0;else if(y<220)ch=1;else if(y<280)ch=2;else ch=3;
    bar=(frame_data>>(64+ch*8))&255;
    if((y>=100&&y<128)||(y>=160&&y<188)||(y>=220&&y<248)||(y>=280&&y<308))rgb=(x-64<bar)?24'h32dda5:24'h223341;
   end
   if(x>=960&&x<1216&&y>=490&&y<612)begin
    spec_index=(x-960)>>4;spec_value=(frame_data>>(160+spec_index*8))&255;
    if((x&15)<12)rgb=(611-y<(spec_value>>1))?24'h32dda5:24'h223341;
   end
   if(y>630&&y<660)begin
    if(x>64&&x<200)rgb=valid?24'h32dda5:24'h607080;
    if(x>224&&x<360)rgb=frame_data[36]?24'hf1b84b:24'h334452;
    if(x>384&&x<520)rgb=frame_data[35]?24'h32dda5:24'h334452;
    if(x>544&&x<680)rgb=frame_data[38]?24'hf1b84b:24'h334452;
    if(x>704&&x<840)rgb=frame_data[58]?24'h32dda5:24'h334452;
    if(x>864&&x<1000)rgb=frame_data[59]?24'h32dda5:24'h334452;
    if(x>1024&&x<1160)rgb=frame_data[60]?24'hff635e:24'h334452;
    if(x>1184&&x<1250)rgb=((|frame_data[132:128])||frame_data[158])?24'hff635e:24'h334452;
   end
   if(text_ink)rgb=text_color;
  end
 end
endmodule
