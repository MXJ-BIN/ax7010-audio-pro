`timescale 1ns/1ps
module fx_stereo(input wire clk,rst,en,eq_enable,reverb_enable,
 input wire signed [23:0] left,right,output reg signed [23:0] out_l,out_r);
 wire signed [23:0] eql,eqr,wet;
 reg signed [23:0] dryl,dryr,mono;
 voice_eq ql(clk,rst,en,left,eql); voice_eq qr(clk,rst,en,right,eqr);
 reverb_lite rev(clk,rst,en,mono,wet);
 function automatic signed [23:0] clip(input signed [27:0] v);
 begin if(v>8388607)clip=8388607;else if(v< -8388608)clip=-8388608;else clip=v[23:0];end
 endfunction
 always @(posedge clk)begin
  if(rst)begin dryl<=0;dryr<=0;mono<=0;out_l<=0;out_r<=0;end
  else if(en)begin : mix
   reg signed [24:0] sum;reg signed [27:0] l,r;
   dryl<=left;dryr<=right;
   sum=eq_enable?$signed(eql):$signed(dryl);sum=sum+(eq_enable?$signed(eqr):$signed(dryr));mono<=sum>>>1;
   l=eq_enable?eql:dryl;r=eq_enable?eqr:dryr;
   if(reverb_enable)begin l=l+(wet>>>3);r=r+(wet>>>3);end
   out_l<=clip(l);out_r<=clip(r);
  end
 end
endmodule
