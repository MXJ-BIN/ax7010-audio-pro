`timescale 1ns/1ps
module audio_conditioner(input wire clk,rst,en,gate_enable,agc_enable,mute,clear_clip,
 input wire [15:0] threshold,input wire [7:0] volume,
 input wire signed [23:0] left,right,output reg signed [23:0] out_l,out_r,
 output reg gate_open,clipped,output reg [11:0] agc_gain,output wire [7:0] output_level);
 reg [23:0] envelope,level_envelope;reg [12:0] hold_count;reg [6:0] pace;reg [8:0] gate_gain;
 reg signed [23:0] gain_l,gain_r,vol_l,vol_r;
 wire [23:0] abs_l=left<0?-left:left,abs_r=right<0?-right:right;
 wire [23:0] peak=abs_l>abs_r?abs_l:abs_r;
 wire [23:0] post_l=gain_l<0?-gain_l:gain_l,post_r=gain_r<0?-gain_r:gain_r;
 wire [23:0] post_peak=post_l>post_r?post_l:post_r;
 wire [23:0] cutoff={threshold,8'd0};
 wire signed [36:0] gl=$signed(left)*$signed({1'b0,(agc_enable?agc_gain:12'd256)});
 wire signed [36:0] gr=$signed(right)*$signed({1'b0,(agc_enable?agc_gain:12'd256)});
 wire signed [32:0] vl=$signed(gain_l)*$signed({1'b0,volume}),vr=$signed(gain_r)*$signed({1'b0,volume});
 wire signed [33:0] ol=$signed(vol_l)*$signed({1'b0,gate_gain}),orr=$signed(vol_r)*$signed({1'b0,gate_gain});
 wire [23:0] out_abs=out_l<0?-out_l:out_l;
 assign output_level=(out_abs>>12)>255?255:out_abs[19:12];
 function automatic signed [23:0] clip(input signed [36:0] v);
 begin if(v>8388607)clip=8388607;else if(v< -8388608)clip=-8388608;else clip=v[23:0];end endfunction
 always @(posedge clk)begin
 if(rst)begin envelope<=0;level_envelope<=0;hold_count<=0;pace<=0;gate_gain<=256;gate_open<=1;agc_gain<=256;clipped<=0;gain_l<=0;gain_r<=0;vol_l<=0;vol_r<=0;out_l<=0;out_r<=0;end
 else begin
 if(clear_clip)clipped<=0;
 if(en)begin
 pace<=pace+1'b1;
 if(peak>envelope)envelope<=peak;else envelope<=envelope-(envelope>>10);
 if(post_peak>level_envelope)level_envelope<=post_peak;else level_envelope<=level_envelope-(level_envelope>>10);
 if(!gate_enable)begin gate_open<=1;hold_count<=0;end
 else if(peak>=cutoff)begin gate_open<=1;hold_count<=4096;end
 else if(hold_count!=0)hold_count<=hold_count-1'b1;
 else if(envelope<(cutoff-(cutoff>>2)))gate_open<=0;
 if(!gate_enable || gate_open)begin if(gate_gain<256)gate_gain<=gate_gain+2;end
 else if(gate_gain>0)gate_gain<=gate_gain-2;
 if(!agc_enable)agc_gain<=256;
 else if(pace==127)begin
 if(level_envelope>2097152 && agc_gain>32)agc_gain<=agc_gain-8;
 else if(level_envelope<1048576 && envelope>cutoff && agc_gain<2048)agc_gain<=agc_gain+1;
 end
 gain_l<=clip(gl>>>8);gain_r<=clip(gr>>>8);vol_l<=clip(vl>>>7);vol_r<=clip(vr>>>7);
 if(mute)begin out_l<=0;out_r<=0;end else begin out_l<=clip(ol>>>8);out_r<=clip(orr>>>8);end
 if(!clear_clip && ((gl>>>8)>8388607 || (gl>>>8)< -8388608 || (gr>>>8)>8388607 || (gr>>>8)< -8388608 || (vl>>>7)>8388607 || (vl>>>7)< -8388608 || (vr>>>7)>8388607 || (vr>>>7)< -8388608))clipped<=1;
 end end end
endmodule
