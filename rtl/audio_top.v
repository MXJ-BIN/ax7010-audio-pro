`timescale 1ns/1ps
// PS GPIO and audio share the physical 50 MHz clock in this design.
// ctrl: [0]PS override [1]mic [2]quiet [3]EQ [4]beam [5]auto [6]reverb
// [16:8]manual x lag Q4, [25:17]manual y lag Q4.
module audio_top(input wire pl_clk_50m,key1_n,key2_n,key3_n,
 input wire mic0_sd,mic1_sd,mic2_sd,mic3_sd,axi_clk,axi_rstn,
 input wire [31:0] ps_ctrl,ps_gains,ps_options,ps_ui,capture_status,input wire clear_clip,
 output reg [31:0] ps_status,output wire [31:0] ps_levels,ps_diagnostics,ps_target,
 output wire record_valid,output wire [31:0] record_pair,
 output wire i2s_bclk,i2s_lrck,i2s_dac_sd, output wire [3:0] led_n,
 output wire hdmi_clk_p,hdmi_clk_n,output wire [2:0] hdmi_d_p,hdmi_d_n,output wire hdmi_out_en);
 wire clk=pl_clk_50m;reg [3:0] startup=15;
 wire rst=(startup!=0)||!axi_rstn;
 (* ASYNC_REG="TRUE" *)reg [2:0] key_meta=7,key_sync=7;
 reg [23:0] heartbeat=0;
 always @(posedge clk)begin
  if(startup!=0)startup<=startup-1'b1;
  key_meta<={key3_n,key2_n,key1_n};key_sync<=key_meta;heartbeat<=heartbeat+1'b1;
 end
 wire en;wire [23:0] rx0,rx1,rx2,rx3;
 wire signed [23:0] hp0,hp1,hp2,hp3,c0,c1,c2,c3,v0,v1,v2,v3,beam,fxl,fxr,clean_l,clean_r;
 wire signed [15:0] tone;
 reg [23:0] txl,txr;
 wire signed [8:0] lx,ly;wire valid,update,overrun;wire [4:0] quality;wire [7:0] frame_seq;
 wire override=ps_ctrl[0];
 wire mic=override?ps_ctrl[1]:!key_sync[0];
 wire quiet=override?ps_ctrl[2]:!key_sync[1];
 wire eq_on=override?ps_ctrl[3]:key_sync[2];
 wire beam_on=override?ps_ctrl[4]:key_sync[2];
 wire auto_on=override?ps_ctrl[5]:1'b1;
 wire rev_on=override?ps_ctrl[6]:1'b0;
 wire signed [8:0] track_x,track_y;
 wire accepted;
 wire gate_on=override && ps_ctrl[7],agc_on=override && ps_ctrl[26],mute_on=override && ps_ctrl[27];
 wire smooth_on=override?ps_ctrl[28]:1'b1;
 wire [3:0] mic_clip;reg [3:0] mic_clip_sticky;
 wire gate_open,output_clip;wire [11:0] agc_gain;wire [7:0] output_level;
 wire [127:0] spectrum_bars;wire [7:0] fft_seq;wire fft_overrun;
 wire signed [8:0] target_x=auto_on?track_x:$signed(ps_ctrl[16:8]);
 wire signed [8:0] target_y=auto_on?track_y:$signed(ps_ctrl[25:17]);
 assign ps_target={14'd0,target_y,target_x};
 i2s_duplex io(.clk(clk),.rst(rst),.tx_left(txl),.tx_right(txr),
 .sd_mic0(mic0_sd),.sd_mic1(mic1_sd),.sd_mic2(mic2_sd),.sd_mic3(mic3_sd),
 .bclk(i2s_bclk),.lrck(i2s_lrck),.sd_dac(i2s_dac_sd),.rx_mic0(rx0),.rx_mic1(rx1),.rx_mic2(rx2),.rx_mic3(rx3),.sample_valid(en));
 dc_block h0(clk,rst,en,rx0,hp0);dc_block h1(clk,rst,en,rx1,hp1);
 dc_block h2(clk,rst,en,rx2,hp2);dc_block h3(clk,rst,en,rx3,hp3);
 mic_gain g0(clk,rst,en,hp0,ps_gains[7:0],c0,mic_clip[0]);
 mic_gain g1(clk,rst,en,hp1,ps_gains[15:8],c1,mic_clip[1]);
 mic_gain g2(clk,rst,en,hp2,ps_gains[23:16],c2,mic_clip[2]);
 mic_gain g3(clk,rst,en,hp3,ps_gains[31:24],c3,mic_clip[3]);
 wire band_valid,band_clip,band_overrun;
 wire [1:0] band_mode=override?ps_options[29:28]:2'd1;
 speech_band voice_band(clk,rst,en,clear_clip,band_mode,c0,c1,c2,c3,v0,v1,v2,v3,band_valid,band_clip,band_overrun);
 doa_square doa(clk,rst,band_valid,v0[23:8],v1[23:8],v2[23:8],v3[23:8],lx,ly,valid,update,quality,frame_seq,overrun);
 direction_track tracker(clk,rst,update,valid,smooth_on,ps_options[26:24],lx,ly,track_x,track_y,accepted);
 beamformer bf(clk,rst,en,v0,v1,v2,v3,target_x,target_y,beam);
 fx_stereo fx(clk,rst,en,eq_on,rev_on,beam_on?beam:v0,beam_on?beam:v1,fxl,fxr);
 audio_conditioner conditioner(clk,rst,en,gate_on,agc_on,mute_on,clear_clip,
 ps_options[15:0],ps_options[23:16],fxl,fxr,clean_l,clean_r,gate_open,output_clip,agc_gain,output_level);
 audio_spectrum spectrum(clk,rst,en,clean_l[23:8],spectrum_bars,fft_seq,fft_overrun);
 assign record_valid=en;
 assign record_pair={clean_l[23:8],hp0[23:8]};
 tone_gen tg(clk,rst,en,tone);
 reg [31:0] levels;reg [5:0] meter_pace;
 assign ps_levels=levels;
 assign ps_diagnostics={band_overrun,band_clip,agc_gain,output_level,capture_status[1],capture_status[0],gate_open,fft_overrun,overrun,output_clip,mic_clip_sticky};
 function automatic [7:0] level(input signed [23:0] v);
 reg [23:0] a;
 begin a=v<0?-v:v;level=(a>>12)>255?255:a[19:12];end
 endfunction
 always @(posedge clk)begin
  if(rst)begin txl<=0;txr<=0;ps_status<=0;levels<=0;meter_pace<=0;mic_clip_sticky<=0;end
  else begin
   if(clear_clip)mic_clip_sticky<=0;else if(en)mic_clip_sticky<=mic_clip_sticky|mic_clip;
   if(update)begin
    ps_status<={frame_seq,quality,accepted,ly,lx};
   end
   if(en)begin
    meter_pace<=meter_pace+1'b1;
    if(level(c0)>levels[7:0])levels[7:0]<=level(c0);else if(meter_pace==63 && levels[7:0]!=0)levels[7:0]<=levels[7:0]-1'b1;
    if(level(c1)>levels[15:8])levels[15:8]<=level(c1);else if(meter_pace==63 && levels[15:8]!=0)levels[15:8]<=levels[15:8]-1'b1;
    if(level(c2)>levels[23:16])levels[23:16]<=level(c2);else if(meter_pace==63 && levels[23:16]!=0)levels[23:16]<=levels[23:16]-1'b1;
    if(level(c3)>levels[31:24])levels[31:24]<=level(c3);else if(meter_pace==63 && levels[31:24]!=0)levels[31:24]<=levels[31:24]-1'b1;
    if(mute_on)begin txl<=0;txr<=0;end
    else if(mic)begin txl<=quiet?($signed(clean_l)>>>2):clean_l;txr<=quiet?($signed(clean_r)>>>2):clean_r;end
    else begin txl<=quiet?{{2{tone[15]}},tone,6'd0}:{tone,8'd0};txr<=quiet?{{2{tone[15]}},tone,6'd0}:{tone,8'd0};end
   end
  end
 end
 assign led_n=accepted?{!(ly<0),!(lx<0),!(ly>0),!(lx>0)}:{4{heartbeat[23]}};
 wire [31:0] display_ctrl={band_mode,smooth_on,mute_on,agc_on,gate_on,target_y,target_x,1'b0,rev_on,auto_on,beam_on,eq_on,quiet,mic,override};
 audio_hdmi video(.pl_clk_50m(clk),.status(ps_status),.control(display_ctrl),.levels(levels),.ui(ps_ui),.diagnostics(ps_diagnostics),.spectrum(spectrum_bars),
 .hdmi_clk_p(hdmi_clk_p),.hdmi_clk_n(hdmi_clk_n),.hdmi_d_p(hdmi_d_p),.hdmi_d_n(hdmi_d_n),.hdmi_out_en(hdmi_out_en));
endmodule
