`timescale 1ns/1ps
// Four synchronized channels, 3 DF1 SOS sections, shared pipelined multiplier.
// Input/output signed 24-bit; states retain 4 fractional bits, coefficients Q16.
// Every channel is committed together in <200 clocks of the 1024-clock sample period.
module speech_band(input wire clk,rst,en,clear_clip,input wire [1:0] mode,
 input wire signed [23:0] din0,din1,din2,din3,
 output reg signed [23:0] out0,out1,out2,out3,
 output reg valid,clipped,overrun);
 reg signed [27:0] x1[0:11],x2[0:11],y1[0:11],y2[0:11];
 reg signed [23:0] frame[0:3],result[0:3];
 reg [1:0] mode_q,previous_mode,channel,section;
 reg [2:0] phase,tap;reg busy;
 reg signed [27:0] work,operand;
 reg signed [17:0] coefficient;
 (* use_dsp="yes" *) reg signed [45:0] product;
 reg signed [49:0] accumulator;
 wire [3:0] slot=channel*3+section;
 wire signed [49:0] rounded=(accumulator+50'sd32768)>>>16;
 wire signed [27:0] next_sample=rounded > 50'sd134217727 ? 28'sd134217727 :
                                rounded < -50'sd134217728 ? 28'sh8000000 : rounded[27:0];
 integer i;
 function automatic signed [17:0] coef(input [1:0] m,s,input [2:0] t);
 begin case({m,s,t})
   7'd32:coef=18'sd64648;
   7'd33:coef=-18'sd129296;
   7'd34:coef=18'sd64648;
   7'd35:coef=-18'sd129283;
   7'd36:coef=18'sd63771;
   7'd40:coef=18'sd5650;
   7'd41:coef=18'sd11300;
   7'd42:coef=18'sd5650;
   7'd43:coef=-18'sd57104;
   7'd44:coef=18'sd14166;
   7'd48:coef=18'sd7333;
   7'd49:coef=18'sd14666;
   7'd50:coef=18'sd7333;
   7'd51:coef=-18'sd74120;
   7'd52:coef=18'sd37917;
   7'd64:coef=18'sd63771;
   7'd65:coef=-18'sd127542;
   7'd66:coef=18'sd63771;
   7'd67:coef=-18'sd127495;
   7'd68:coef=18'sd62054;
   7'd72:coef=18'sd2918;
   7'd73:coef=18'sd5836;
   7'd74:coef=18'sd2918;
   7'd75:coef=-18'sd78422;
   7'd76:coef=18'sd24559;
   7'd80:coef=18'sd3573;
   7'd81:coef=18'sd7146;
   7'd82:coef=18'sd3573;
   7'd83:coef=-18'sd96003;
   7'd84:coef=18'sd44758;
   7'd96:coef=18'sd63771;
   7'd97:coef=-18'sd127542;
   7'd98:coef=18'sd63771;
   7'd99:coef=-18'sd127495;
   7'd100:coef=18'sd62054;
   7'd104:coef=18'sd2218;
   7'd105:coef=18'sd4436;
   7'd106:coef=18'sd2218;
   7'd107:coef=-18'sd85326;
   7'd108:coef=18'sd28663;
   7'd112:coef=18'sd2656;
   7'd113:coef=18'sd5312;
   7'd114:coef=18'sd2656;
   7'd115:coef=-18'sd102162;
   7'd116:coef=18'sd47249;
 default:coef=0;
 endcase end endfunction
 always @(posedge clk)begin
  if(rst)begin
   out0<=0;out1<=0;out2<=0;out3<=0;valid<=0;clipped<=0;overrun<=0;
   busy<=0;mode_q<=0;previous_mode<=0;channel<=0;section<=0;phase<=0;tap<=0;
   work<=0;operand<=0;coefficient<=0;product<=0;accumulator<=0;
   for(i=0;i<12;i=i+1)begin x1[i]<=0;x2[i]<=0;y1[i]<=0;y2[i]<=0;end
   for(i=0;i<4;i=i+1)begin frame[i]<=0;result[i]<=0;end
  end else begin
   valid<=0;if(clear_clip)begin clipped<=0;overrun<=0;end
   product<=operand*coefficient;
   if(en)begin
    if(busy)overrun<=1;
    else begin
     frame[0]<=din0;frame[1]<=din1;frame[2]<=din2;frame[3]<=din3;
     mode_q<=mode;previous_mode<=mode;busy<=1;phase<=5;channel<=0;section<=0;tap<=0;accumulator<=0;
     if(mode!=previous_mode)for(i=0;i<12;i=i+1)begin x1[i]<=0;x2[i]<=0;y1[i]<=0;y2[i]<=0;end
    end
   end
   if(busy)case(phase)
    5:begin
     if(mode_q==0)begin out0<=frame[0];out1<=frame[1];out2<=frame[2];out3<=frame[3];valid<=1;busy<=0;end
     else begin work<={frame[0],4'b0};phase<=0;end
    end
    0:begin
     coefficient<=coef(mode_q,section,tap);
     case(tap)0:operand<=work;1:operand<=x1[slot];2:operand<=x2[slot];3:operand<=y1[slot];default:operand<=y2[slot];endcase
     phase<=1;
    end
    1:phase<=2;
    2:begin
     accumulator<=tap>=3?accumulator-$signed(product):accumulator+$signed(product);
     if(tap==4)phase<=3;else begin tap<=tap+1'b1;phase<=0;end
    end
    3:begin
     if(!clear_clip && (rounded>134217727 || rounded< -134217728))clipped<=1;
     x2[slot]<=x1[slot];x1[slot]<=work;y2[slot]<=y1[slot];y1[slot]<=next_sample;
     accumulator<=0;tap<=0;
     if(section==2)begin
      result[channel]<=next_sample>>>4;section<=0;
      if(channel==3)phase<=4;
      else begin channel<=channel+1'b1;work<={frame[channel+1'b1],4'b0};phase<=0;end
     end else begin section<=section+1'b1;work<=next_sample;phase<=0;end
    end
    4:begin out0<=result[0];out1<=result[1];out2<=result[2];out3<=result[3];valid<=1;busy<=0;end
    default:begin busy<=0;overrun<=1;end
   endcase
  end
 end
endmodule
