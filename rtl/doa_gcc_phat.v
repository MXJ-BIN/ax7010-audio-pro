`timescale 1ns/1ps
// Four-channel GCC-PHAT: four forward transforms, four pair IFFTs on one
// dedicated engine. Display FFT is independent. All RAM reads are synchronous.
module doa_gcc_phat #(parameter MAX_LAG=8, ENERGY_MIN=2097152,
 PHAT_EPSILON=64, PEAK_MIN=2048)(
 input wire clk,rst,en,input wire signed [15:0] m0,m1,m2,m3,
 output reg signed [8:0] lag_x,lag_y,output reg valid,update,
 output reg [4:0] quality,output reg [7:0] frame_seq,output reg overrun);
 localparam IDLE=0,LWAIT=1,LOAD=2,FSTART=3,FWAIT=4,SWAIT=5,SAVE=6,
 GWAIT=7,CROSS=8,NORM=9,DIVIDE=10,PHAT=11,ISTART=12,IWAIT=13,
 PWAIT=14,PEAK=15,INTERP=16,FRAC=17,CONF=18,NEXT=19,PUBLISH=20;
 reg [4:0] state;reg [8:0] wr,idx;reg bank,readbank;
 reg [1:0] channel,pair;reg [47:0] energy[0:3],block_energy[0:3];
 wire signed [31:0] e0=m0*m0,e1=m1*m1,e2=m2*m2,e3=m3*m3;
 // A late frame is discarded in the capture bank; NEVER toggle onto locked RAM.
 (* ram_style="block" *)reg [63:0] capture[0:1023];reg [63:0] capture_q;
 always @(posedge clk)begin
 if(en && !rst)capture[{bank,wr}]<={m3,m2,m1,m0};
 capture_q<=capture[{readbank,idx}];
 end
 wire [31:0] fq;wire fbusy,fdone;reg [31:0] fdata;reg [8:0] faddr;
 wire fload=state==LOAD || state==PHAT;
 wire fstart=state==FSTART || state==ISTART;
 doa_fft512 fft(clk,rst,fstart,state==ISTART,fload,idx,fdata,faddr,fq,fbusy,fdone);
 // 4 x 512 complex spectra; one write/read port and one read port.
 wire [31:0] sq_a,sq_b;
 reg [10:0] sa,sb;reg [1:0] ca,cb;
 always @*begin
 case(pair)
 0:begin ca=0;cb=1;end 1:begin ca=3;cb=2;end
 2:begin ca=0;cb=3;end default:begin ca=1;cb=2;end
 endcase
 sa=(state==SAVE || state==SWAIT)?{channel,idx}:{ca,idx};sb={cb,idx};
 end
 xpm_memory_tdpram #(.MEMORY_SIZE(65536),.MEMORY_PRIMITIVE("block"),
 .CLOCKING_MODE("common_clock"),.USE_MEM_INIT(0),.SIM_ASSERT_CHK(1),
 .WRITE_DATA_WIDTH_A(32),.WRITE_DATA_WIDTH_B(32),.READ_DATA_WIDTH_A(32),.READ_DATA_WIDTH_B(32),
 .BYTE_WRITE_WIDTH_A(32),.BYTE_WRITE_WIDTH_B(32),.ADDR_WIDTH_A(11),.ADDR_WIDTH_B(11),
 .READ_LATENCY_A(1),.READ_LATENCY_B(1),.WRITE_MODE_A("read_first"),.WRITE_MODE_B("read_first")) spectrum_ram(
 .sleep(1'b0),.clka(clk),.clkb(clk),.rsta(1'b0),.rstb(1'b0),.ena(!rst),.enb(!rst),
 .regcea(1'b1),.regceb(1'b1),.wea(state==SAVE && !rst),.web(1'b0),
 .addra(sa),.addrb(sb),.dina(fq),.dinb(32'd0),.douta(sq_a),.doutb(sq_b),
 .injectsbiterra(1'b0),.injectdbiterra(1'b0),.injectsbiterrb(1'b0),.injectdbiterrb(1'b0),
 .sbiterra(),.dbiterra(),.sbiterrb(),.dbiterrb());


 wire signed [31:0] p0=$signed(sq_a[15:0])*$signed(sq_b[15:0]);
 wire signed [31:0] p1=$signed(sq_a[31:16])*$signed(sq_b[31:16]);
 wire signed [31:0] p2=$signed(sq_a[31:16])*$signed(sq_b[15:0]);
 wire signed [31:0] p3=$signed(sq_a[15:0])*$signed(sq_b[31:16]);
 reg signed [32:0] gr,gi;reg [34:0] den,remr,remi;
 reg [13:0] qr,qi;reg [3:0] bitcount;reg negr,negi;
 wire [35:0] trialr={remr,1'b0},triali={remi,1'b0};
 reg [5:0] li,besti,scan;reg signed [7:0] lag;
 reg signed [15:0] best,scores[0:2*MAX_LAG];
 reg signed [8:0] delays[0:3];reg [3:0] good;
 reg [20:0] sidelobe_sum;reg [4:0] qmin;
 reg [20:0] fraction_rem,fraction_den;reg [3:0] fraction;reg frac_negative;
 integer k;
 always @*begin
 faddr=idx;fdata=0;
 if(state==LOAD)fdata={16'd0,capture_q[channel*16+:16]};
 if(state==PHAT)fdata={negi?-$signed({2'b0,qi}):$signed({2'b0,qi}),negr?-$signed({2'b0,qr}):$signed({2'b0,qr})};
 // IFFT(Xa*conj(Xb)) has opposite lag sign to sum a[n]*b[n+lag].
 if(state==PWAIT || state==PEAK)faddr=(lag<=0)?-lag:512-lag;
 end
 always @(posedge clk)begin
 if(rst)begin
 state<=IDLE;wr<=0;idx<=0;bank<=0;readbank<=0;channel<=0;pair<=0;
 lag_x<=0;lag_y<=0;valid<=0;update<=0;quality<=0;frame_seq<=0;overrun<=0;
 gr<=0;gi<=0;den<=1;remr<=0;remi<=0;qr<=0;qi<=0;bitcount<=0;negr<=0;negi<=0;
 li<=0;besti<=0;scan<=0;lag<=-MAX_LAG;best<=-32768;good<=0;sidelobe_sum<=0;qmin<=31;
 fraction_rem<=0;fraction_den<=0;fraction<=0;frac_negative<=0;
 for(k=0;k<4;k=k+1)begin energy[k]<=0;block_energy[k]<=0;delays[k]<=0;end
 end else begin
 update<=0;
 if(en)begin
 if(wr==511)begin
 wr<=0;for(k=0;k<4;k=k+1)energy[k]<=0;
 if(state==IDLE)begin
 bank<=~bank;readbank<=bank;idx<=0;channel<=0;pair<=0;state<=LWAIT;good<=0;qmin<=31;
 block_energy[0]<=energy[0]+{16'd0,e0};block_energy[1]<=energy[1]+{16'd0,e1};
 block_energy[2]<=energy[2]+{16'd0,e2};block_energy[3]<=energy[3]+{16'd0,e3};
 end else overrun<=1;
 end else begin
 wr<=wr+1'b1;energy[0]<=energy[0]+{16'd0,e0};energy[1]<=energy[1]+{16'd0,e1};
 energy[2]<=energy[2]+{16'd0,e2};energy[3]<=energy[3]+{16'd0,e3};
 end end
 case(state)
 LWAIT:state<=LOAD;
 LOAD:if(idx==511)begin idx<=0;state<=FSTART;end else begin idx<=idx+1'b1;state<=LWAIT;end
 FSTART:state<=FWAIT;
 FWAIT:if(fdone)begin idx<=0;state<=SWAIT;end
 SWAIT:state<=SAVE;
 SAVE:if(idx==511)begin idx<=0;
 if(channel==3)begin pair<=0;state<=GWAIT;end
 else begin channel<=channel+1'b1;state<=LWAIT;end
 end else begin idx<=idx+1'b1;state<=SWAIT;end
 GWAIT:state<=CROSS;
 CROSS:begin gr<=$signed({p0[31],p0})+$signed({p1[31],p1});
 gi<=$signed({p2[31],p2})-$signed({p3[31],p3});state<=NORM;end
 NORM:begin : magnitude
 reg [32:0] ar,ai;reg [34:0] hi,lo;
 ar=gr<0?-gr:gr;ai=gi<0?-gi:gi;hi=ar>ai?ar:ai;lo=ar>ai?ai:ar;
 // max + 0.5 min overestimates Euclidean norm by <=11.81%; no amplification.
 den<=hi+(lo>>1)+PHAT_EPSILON;remr<={2'd0,ar};remi<={2'd0,ai};
 negr<=gr<0;negi<=gi<0;qr<=0;qi<=0;bitcount<=0;
 // Remove DC and Nyquist; avoid unreliable bins with no cross power.
 if(idx==0 || idx==256 || hi<PHAT_EPSILON)state<=PHAT;else state<=DIVIDE;
 end
 DIVIDE:begin
 if(trialr>={1'b0,den})begin remr<=trialr-{1'b0,den};qr<={qr[12:0],1'b1};end
 else begin remr<=trialr;qr<={qr[12:0],1'b0};end
 if(triali>={1'b0,den})begin remi<=triali-{1'b0,den};qi<={qi[12:0],1'b1};end
 else begin remi<=triali;qi<={qi[12:0],1'b0};end
 if(bitcount==13)state<=PHAT;else bitcount<=bitcount+1'b1;
 end
 PHAT:if(idx==511)begin idx<=0;state<=ISTART;end else begin idx<=idx+1'b1;state<=GWAIT;end
 ISTART:state<=IWAIT;
 IWAIT:if(fdone)begin li<=0;lag<=-MAX_LAG;best<=-32768;besti<=0;state<=PWAIT;end
 PWAIT:state<=PEAK;
 PEAK:begin
 scores[li]<=$signed(fq[15:0]);
 if($signed(fq[15:0])>best)begin best<=fq[15:0];besti<=li;end
 if(li==2*MAX_LAG)state<=INTERP;
 else begin li<=li+1'b1;lag<=lag+1'b1;state<=PWAIT;end
 end
 INTERP:begin : interpolate
 reg signed [20:0] leftv,rightv,center,curvature,num;reg [20:0] ad,an;
 delays[pair]<=($signed({1'b0,besti})-MAX_LAG)*16;
 good[pair]<=block_energy[ca]>=ENERGY_MIN && block_energy[cb]>=ENERGY_MIN && best>=PEAK_MIN && besti>0 && besti<2*MAX_LAG;
 scan<=0;sidelobe_sum<=0;fraction<=0;
 if(besti>0 && besti<2*MAX_LAG)begin
 leftv=scores[besti-1];rightv=scores[besti+1];center=best;
 curvature=leftv-(center<<<1)+rightv;num=(leftv-rightv)<<<3;
 ad=curvature<0?-curvature:curvature;an=num<0?-num:num;
 fraction_rem<=an+(ad>>1);fraction_den<=ad;frac_negative<=(num<0)^(curvature<0);state<=FRAC;
 end else state<=CONF;
 end
 FRAC:if(fraction_den!=0 && fraction_rem>=fraction_den && fraction<8)begin
 fraction_rem<=fraction_rem-fraction_den;fraction<=fraction+1'b1;
 end else begin
 delays[pair]<=frac_negative?delays[pair]-$signed({1'b0,fraction}):delays[pair]+$signed({1'b0,fraction});state<=CONF;
 end
 CONF:begin : confidence
 reg [15:0] a;reg signed [18:0] side,peak_wide;
 a=scores[scan]<0?-scores[scan]:scores[scan];sidelobe_sum<=sidelobe_sum+{5'd0,a};
 side=scores[scan];peak_wide=best;
 // Reject competing non-neighbour peaks above 75% of the selected peak.
 if((scan+1<besti || scan>besti+1) && (side<<<2)>((peak_wide<<<1)+peak_wide))good[pair]<=0;
 if(scan==2*MAX_LAG)state<=NEXT;else scan<=scan+1'b1;
 end
 NEXT:begin
 // Peak / mean(abs(search window)) must be >=3; 24-bit intermediate.
 if($signed(best)*(2*MAX_LAG+1)<$signed({1'b0,sidelobe_sum})*3)begin good[pair]<=0;qmin<=0;end
 if(pair==3)state<=PUBLISH;else begin pair<=pair+1'b1;idx<=0;state<=GWAIT;end
 end
 PUBLISH:begin : publish
 reg signed [9:0] sx,sy,dx,dy;reg ok;
 sx=$signed(delays[0]);sx=sx+$signed(delays[1]);sy=$signed(delays[2]);sy=sy+$signed(delays[3]);
 dx=$signed(delays[0]);dx=dx-$signed(delays[1]);dy=$signed(delays[2]);dy=dy-$signed(delays[3]);
 ok=(&good) && dx<=16 && dx>=-16 && dy<=16 && dy>=-16;
 valid<=ok;quality<=ok?qmin:0;
 // Invalid frames publish status but hold the last accepted raw delay.
 if(ok)begin lag_x<=sx>>>1;lag_y<=sy>>>1;end
 frame_seq<=frame_seq+1'b1;update<=1;state<=IDLE;
 end
 endcase
 end end
endmodule
