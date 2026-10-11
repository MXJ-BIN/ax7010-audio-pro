`timescale 1ns/1ps
// 512-point radix-2 FFT, 1/2 per stage; spectral display, not PHAT or audio processing.
module audio_spectrum(input wire clk,rst,en,input wire signed [15:0] sample,
 output reg [127:0] bars,output reg [7:0] frame_seq,output reg overrun);
 (* ram_style="distributed" *)reg signed [15:0] capture[0:1023];
 reg [8:0] wr,load_index;reg bank,readbank;
 reg signed [15:0] capture_q;

 wire [31:0] qa,qb;reg [8:0] addr_a,addr_b;reg we_a,we_b;reg [31:0] data_a,data_b;
 reg [3:0] state,stage,bin_index;reg [8:0] base,j;
 wire [9:0] half_size=10'd1<<stage;
 wire [9:0] step_size=half_size<<1;
 wire [7:0] tw_index=j<<(8-stage);
 reg [31:0] twiddle,tw_q;
 reg signed [31:0] m0,m1,m2,m3;
 reg signed [15:0] ar,ai;
 reg signed [17:0] tr,ti;
 reg [127:0] bars_work;
 wire signed [32:0] rr=$signed({m0[31],m0})-$signed({m1[31],m1});
 wire signed [32:0] ii=$signed({m2[31],m2})+$signed({m3[31],m3});
 function [8:0] reverse9(input [8:0] v);integer k;begin for(k=0;k<9;k=k+1)reverse9[k]=v[8-k];end endfunction
 function signed [15:0] clip16(input signed [18:0] v);begin if(v>32767)clip16=32767;else if(v< -32768)clip16=-32768;else clip16=v[15:0];end endfunction
 function [8:0] selected_bin(input [3:0] n);begin case(n)
 0:selected_bin=1;1:selected_bin=2;2:selected_bin=3;3:selected_bin=4;4:selected_bin=5;5:selected_bin=6;6:selected_bin=8;7:selected_bin=10;
 8:selected_bin=12;9:selected_bin=16;10:selected_bin=20;11:selected_bin=24;12:selected_bin=32;13:selected_bin=40;14:selected_bin=48;15:selected_bin=64;
 endcase end endfunction
 always @*begin case(tw_index)
  8'd0:twiddle=32'h00007fff;
  8'd1:twiddle=32'hfe6e7ffd;
  8'd2:twiddle=32'hfcdc7ff5;
  8'd3:twiddle=32'hfb4a7fe9;
  8'd4:twiddle=32'hf9b87fd8;
  8'd5:twiddle=32'hf8277fc1;
  8'd6:twiddle=32'hf6967fa6;
  8'd7:twiddle=32'hf5057f86;
  8'd8:twiddle=32'hf3747f61;
  8'd9:twiddle=32'hf1e47f37;
  8'd10:twiddle=32'hf0557f09;
  8'd11:twiddle=32'heec67ed5;
  8'd12:twiddle=32'hed387e9c;
  8'd13:twiddle=32'hebab7e5f;
  8'd14:twiddle=32'hea1e7e1d;
  8'd15:twiddle=32'he8927dd5;
  8'd16:twiddle=32'he7077d89;
  8'd17:twiddle=32'he57e7d39;
  8'd18:twiddle=32'he3f57ce3;
  8'd19:twiddle=32'he26d7c88;
  8'd20:twiddle=32'he0e67c29;
  8'd21:twiddle=32'hdf617bc5;
  8'd22:twiddle=32'hdddd7b5c;
  8'd23:twiddle=32'hdc5a7aee;
  8'd24:twiddle=32'hdad87a7c;
  8'd25:twiddle=32'hd9587a05;
  8'd26:twiddle=32'hd7da7989;
  8'd27:twiddle=32'hd65d7909;
  8'd28:twiddle=32'hd4e17884;
  8'd29:twiddle=32'hd36777fa;
  8'd30:twiddle=32'hd1ef776b;
  8'd31:twiddle=32'hd07976d8;
  8'd32:twiddle=32'hcf057641;
  8'd33:twiddle=32'hcd9275a5;
  8'd34:twiddle=32'hcc217504;
  8'd35:twiddle=32'hcab3745f;
  8'd36:twiddle=32'hc94673b5;
  8'd37:twiddle=32'hc7dc7307;
  8'd38:twiddle=32'hc6747254;
  8'd39:twiddle=32'hc50e719d;
  8'd40:twiddle=32'hc3aa70e2;
  8'd41:twiddle=32'hc2487022;
  8'd42:twiddle=32'hc0e96f5e;
  8'd43:twiddle=32'hbf8d6e96;
  8'd44:twiddle=32'hbe326dc9;
  8'd45:twiddle=32'hbcdb6cf8;
  8'd46:twiddle=32'hbb866c23;
  8'd47:twiddle=32'hba336b4a;
  8'd48:twiddle=32'hb8e46a6d;
  8'd49:twiddle=32'hb797698b;
  8'd50:twiddle=32'hb64c68a6;
  8'd51:twiddle=32'hb50567bc;
  8'd52:twiddle=32'hb3c166cf;
  8'd53:twiddle=32'hb27f65dd;
  8'd54:twiddle=32'hb14164e8;
  8'd55:twiddle=32'hb00563ee;
  8'd56:twiddle=32'haecd62f1;
  8'd57:twiddle=32'had9861f0;
  8'd58:twiddle=32'hac6560eb;
  8'd59:twiddle=32'hab375fe3;
  8'd60:twiddle=32'haa0b5ed7;
  8'd61:twiddle=32'ha8e35dc7;
  8'd62:twiddle=32'ha7be5cb3;
  8'd63:twiddle=32'ha69c5b9c;
  8'd64:twiddle=32'ha57e5a82;
  8'd65:twiddle=32'ha4645964;
  8'd66:twiddle=32'ha34d5842;
  8'd67:twiddle=32'ha239571d;
  8'd68:twiddle=32'ha12955f5;
  8'd69:twiddle=32'ha01d54c9;
  8'd70:twiddle=32'h9f15539b;
  8'd71:twiddle=32'h9e105268;
  8'd72:twiddle=32'h9d0f5133;
  8'd73:twiddle=32'h9c124ffb;
  8'd74:twiddle=32'h9b184ebf;
  8'd75:twiddle=32'h9a234d81;
  8'd76:twiddle=32'h99314c3f;
  8'd77:twiddle=32'h98444afb;
  8'd78:twiddle=32'h975a49b4;
  8'd79:twiddle=32'h96754869;
  8'd80:twiddle=32'h9593471c;
  8'd81:twiddle=32'h94b645cd;
  8'd82:twiddle=32'h93dd447a;
  8'd83:twiddle=32'h93084325;
  8'd84:twiddle=32'h923741ce;
  8'd85:twiddle=32'h916a4073;
  8'd86:twiddle=32'h90a23f17;
  8'd87:twiddle=32'h8fde3db8;
  8'd88:twiddle=32'h8f1e3c56;
  8'd89:twiddle=32'h8e633af2;
  8'd90:twiddle=32'h8dac398c;
  8'd91:twiddle=32'h8cf93824;
  8'd92:twiddle=32'h8c4b36ba;
  8'd93:twiddle=32'h8ba1354d;
  8'd94:twiddle=32'h8afc33df;
  8'd95:twiddle=32'h8a5b326e;
  8'd96:twiddle=32'h89bf30fb;
  8'd97:twiddle=32'h89282f87;
  8'd98:twiddle=32'h88952e11;
  8'd99:twiddle=32'h88062c99;
  8'd100:twiddle=32'h877c2b1f;
  8'd101:twiddle=32'h86f729a3;
  8'd102:twiddle=32'h86772826;
  8'd103:twiddle=32'h85fb26a8;
  8'd104:twiddle=32'h85842528;
  8'd105:twiddle=32'h851223a6;
  8'd106:twiddle=32'h84a42223;
  8'd107:twiddle=32'h843b209f;
  8'd108:twiddle=32'h83d71f1a;
  8'd109:twiddle=32'h83781d93;
  8'd110:twiddle=32'h831d1c0b;
  8'd111:twiddle=32'h82c71a82;
  8'd112:twiddle=32'h827718f9;
  8'd113:twiddle=32'h822b176e;
  8'd114:twiddle=32'h81e315e2;
  8'd115:twiddle=32'h81a11455;
  8'd116:twiddle=32'h816412c8;
  8'd117:twiddle=32'h812b113a;
  8'd118:twiddle=32'h80f70fab;
  8'd119:twiddle=32'h80c90e1c;
  8'd120:twiddle=32'h809f0c8c;
  8'd121:twiddle=32'h807a0afb;
  8'd122:twiddle=32'h805a096a;
  8'd123:twiddle=32'h803f07d9;
  8'd124:twiddle=32'h80280648;
  8'd125:twiddle=32'h801704b6;
  8'd126:twiddle=32'h800b0324;
  8'd127:twiddle=32'h80030192;
  8'd128:twiddle=32'h80010000;
  8'd129:twiddle=32'h8003fe6e;
  8'd130:twiddle=32'h800bfcdc;
  8'd131:twiddle=32'h8017fb4a;
  8'd132:twiddle=32'h8028f9b8;
  8'd133:twiddle=32'h803ff827;
  8'd134:twiddle=32'h805af696;
  8'd135:twiddle=32'h807af505;
  8'd136:twiddle=32'h809ff374;
  8'd137:twiddle=32'h80c9f1e4;
  8'd138:twiddle=32'h80f7f055;
  8'd139:twiddle=32'h812beec6;
  8'd140:twiddle=32'h8164ed38;
  8'd141:twiddle=32'h81a1ebab;
  8'd142:twiddle=32'h81e3ea1e;
  8'd143:twiddle=32'h822be892;
  8'd144:twiddle=32'h8277e707;
  8'd145:twiddle=32'h82c7e57e;
  8'd146:twiddle=32'h831de3f5;
  8'd147:twiddle=32'h8378e26d;
  8'd148:twiddle=32'h83d7e0e6;
  8'd149:twiddle=32'h843bdf61;
  8'd150:twiddle=32'h84a4dddd;
  8'd151:twiddle=32'h8512dc5a;
  8'd152:twiddle=32'h8584dad8;
  8'd153:twiddle=32'h85fbd958;
  8'd154:twiddle=32'h8677d7da;
  8'd155:twiddle=32'h86f7d65d;
  8'd156:twiddle=32'h877cd4e1;
  8'd157:twiddle=32'h8806d367;
  8'd158:twiddle=32'h8895d1ef;
  8'd159:twiddle=32'h8928d079;
  8'd160:twiddle=32'h89bfcf05;
  8'd161:twiddle=32'h8a5bcd92;
  8'd162:twiddle=32'h8afccc21;
  8'd163:twiddle=32'h8ba1cab3;
  8'd164:twiddle=32'h8c4bc946;
  8'd165:twiddle=32'h8cf9c7dc;
  8'd166:twiddle=32'h8dacc674;
  8'd167:twiddle=32'h8e63c50e;
  8'd168:twiddle=32'h8f1ec3aa;
  8'd169:twiddle=32'h8fdec248;
  8'd170:twiddle=32'h90a2c0e9;
  8'd171:twiddle=32'h916abf8d;
  8'd172:twiddle=32'h9237be32;
  8'd173:twiddle=32'h9308bcdb;
  8'd174:twiddle=32'h93ddbb86;
  8'd175:twiddle=32'h94b6ba33;
  8'd176:twiddle=32'h9593b8e4;
  8'd177:twiddle=32'h9675b797;
  8'd178:twiddle=32'h975ab64c;
  8'd179:twiddle=32'h9844b505;
  8'd180:twiddle=32'h9931b3c1;
  8'd181:twiddle=32'h9a23b27f;
  8'd182:twiddle=32'h9b18b141;
  8'd183:twiddle=32'h9c12b005;
  8'd184:twiddle=32'h9d0faecd;
  8'd185:twiddle=32'h9e10ad98;
  8'd186:twiddle=32'h9f15ac65;
  8'd187:twiddle=32'ha01dab37;
  8'd188:twiddle=32'ha129aa0b;
  8'd189:twiddle=32'ha239a8e3;
  8'd190:twiddle=32'ha34da7be;
  8'd191:twiddle=32'ha464a69c;
  8'd192:twiddle=32'ha57ea57e;
  8'd193:twiddle=32'ha69ca464;
  8'd194:twiddle=32'ha7bea34d;
  8'd195:twiddle=32'ha8e3a239;
  8'd196:twiddle=32'haa0ba129;
  8'd197:twiddle=32'hab37a01d;
  8'd198:twiddle=32'hac659f15;
  8'd199:twiddle=32'had989e10;
  8'd200:twiddle=32'haecd9d0f;
  8'd201:twiddle=32'hb0059c12;
  8'd202:twiddle=32'hb1419b18;
  8'd203:twiddle=32'hb27f9a23;
  8'd204:twiddle=32'hb3c19931;
  8'd205:twiddle=32'hb5059844;
  8'd206:twiddle=32'hb64c975a;
  8'd207:twiddle=32'hb7979675;
  8'd208:twiddle=32'hb8e49593;
  8'd209:twiddle=32'hba3394b6;
  8'd210:twiddle=32'hbb8693dd;
  8'd211:twiddle=32'hbcdb9308;
  8'd212:twiddle=32'hbe329237;
  8'd213:twiddle=32'hbf8d916a;
  8'd214:twiddle=32'hc0e990a2;
  8'd215:twiddle=32'hc2488fde;
  8'd216:twiddle=32'hc3aa8f1e;
  8'd217:twiddle=32'hc50e8e63;
  8'd218:twiddle=32'hc6748dac;
  8'd219:twiddle=32'hc7dc8cf9;
  8'd220:twiddle=32'hc9468c4b;
  8'd221:twiddle=32'hcab38ba1;
  8'd222:twiddle=32'hcc218afc;
  8'd223:twiddle=32'hcd928a5b;
  8'd224:twiddle=32'hcf0589bf;
  8'd225:twiddle=32'hd0798928;
  8'd226:twiddle=32'hd1ef8895;
  8'd227:twiddle=32'hd3678806;
  8'd228:twiddle=32'hd4e1877c;
  8'd229:twiddle=32'hd65d86f7;
  8'd230:twiddle=32'hd7da8677;
  8'd231:twiddle=32'hd95885fb;
  8'd232:twiddle=32'hdad88584;
  8'd233:twiddle=32'hdc5a8512;
  8'd234:twiddle=32'hdddd84a4;
  8'd235:twiddle=32'hdf61843b;
  8'd236:twiddle=32'he0e683d7;
  8'd237:twiddle=32'he26d8378;
  8'd238:twiddle=32'he3f5831d;
  8'd239:twiddle=32'he57e82c7;
  8'd240:twiddle=32'he7078277;
  8'd241:twiddle=32'he892822b;
  8'd242:twiddle=32'hea1e81e3;
  8'd243:twiddle=32'hebab81a1;
  8'd244:twiddle=32'hed388164;
  8'd245:twiddle=32'heec6812b;
  8'd246:twiddle=32'hf05580f7;
  8'd247:twiddle=32'hf1e480c9;
  8'd248:twiddle=32'hf374809f;
  8'd249:twiddle=32'hf505807a;
  8'd250:twiddle=32'hf696805a;
  8'd251:twiddle=32'hf827803f;
  8'd252:twiddle=32'hf9b88028;
  8'd253:twiddle=32'hfb4a8017;
  8'd254:twiddle=32'hfcdc800b;
  8'd255:twiddle=32'hfe6e8003;
 default:twiddle=32'h00007fff;
 endcase end
 always @*begin : ports
 reg signed [18:0] apr,api,bpr,bpi;
 addr_a=base+j;addr_b=base+j+half_size;we_a=0;we_b=0;data_a=0;data_b=0;
 apr=$signed(ar);apr=apr+$signed(tr);api=$signed(ai);api=api+$signed(ti);
 bpr=$signed(ar);bpr=bpr-$signed(tr);bpi=$signed(ai);bpi=bpi-$signed(ti);
 if(state==1 || state==2)begin addr_a=reverse9(load_index);if(state==2)begin we_a=1;data_a={16'd0,capture_q};end end
 if(state==6)begin we_a=1;we_b=1;data_a={clip16(api>>>1),clip16(apr>>>1)};data_b={clip16(bpi>>>1),clip16(bpr>>>1)};end
 if(state==7 || state==8)addr_a=selected_bin(bin_index);
 end
 // Explicit XPM guarantees a block RAM instead of expensive register expansion.
 xpm_memory_tdpram #(.MEMORY_SIZE(16384),.MEMORY_PRIMITIVE("block"),
 .CLOCKING_MODE("common_clock"),.USE_MEM_INIT(0),.SIM_ASSERT_CHK(1),
 .WRITE_DATA_WIDTH_A(32),.WRITE_DATA_WIDTH_B(32),.READ_DATA_WIDTH_A(32),.READ_DATA_WIDTH_B(32),
 .BYTE_WRITE_WIDTH_A(32),.BYTE_WRITE_WIDTH_B(32),.ADDR_WIDTH_A(9),.ADDR_WIDTH_B(9),
 .READ_LATENCY_A(1),.READ_LATENCY_B(1),.WRITE_MODE_A("read_first"),.WRITE_MODE_B("read_first")) work_ram(
 .sleep(1'b0),.clka(clk),.clkb(clk),.rsta(1'b0),.rstb(1'b0),.ena(!rst),.enb(!rst),
 .regcea(1'b1),.regceb(1'b1),.wea(we_a && !rst),.web(we_b && !rst),
 .addra(addr_a),.addrb(addr_b),.dina(data_a),.dinb(data_b),.douta(qa),.doutb(qb),
 .injectsbiterra(1'b0),.injectdbiterra(1'b0),.injectsbiterrb(1'b0),.injectdbiterrb(1'b0),
 .sbiterra(),.dbiterra(),.sbiterrb(),.dbiterrb());
 always @(posedge clk)begin
 capture_q<=capture[{readbank,load_index}];
 tw_q<=twiddle;
 end
 always @(posedge clk)begin
 if(rst)begin wr<=0;bank<=0;readbank<=0;load_index<=0;state<=0;stage<=0;base<=0;j<=0;bars<=0;bars_work<=0;bin_index<=0;frame_seq<=0;overrun<=0;m0<=0;m1<=0;m2<=0;m3<=0;ar<=0;ai<=0;tr<=0;ti<=0;end
 else begin
 if(en)begin
 capture[{bank,wr}]<=sample;
 if(wr==511)begin
 wr<=0;bank<=~bank;
 if(state==0)begin readbank<=bank;load_index<=0;state<=1;end else overrun<=1;
 end else wr<=wr+1'b1;
 end
 case(state)
 1:state<=2;
 2:begin if(load_index==511)begin stage<=0;base<=0;j<=0;state<=3;end else begin load_index<=load_index+1'b1;state<=1;end end
 3:state<=4;
 4:begin
 ar<=qa[15:0];ai<=qa[31:16];
 m0<=$signed(qb[15:0])*$signed(tw_q[15:0]);m1<=$signed(qb[31:16])*$signed(tw_q[31:16]);
 m2<=$signed(qb[15:0])*$signed(tw_q[31:16]);m3<=$signed(qb[31:16])*$signed(tw_q[15:0]);state<=5;
 end
 5:begin tr<=rr>>>15;ti<=ii>>>15;state<=6;end
 6:begin
 state<=3;
 if(j<half_size-1)j<=j+1'b1;
 else begin j<=0;if(base+step_size<512)base<=base+step_size;
 else begin base<=0;if(stage<8)stage<=stage+1'b1;else begin bin_index<=0;state<=7;end end end
 end
 7:state<=8;
 8:begin : magnitude
 reg [15:0] rabs,iabs;reg [16:0] magnitude;reg [7:0] level;integer k;
 rabs=$signed(qa[15:0])<0?-$signed(qa[15:0]):qa[15:0];iabs=$signed(qa[31:16])<0?-$signed(qa[31:16]):qa[31:16];
 magnitude={1'b0,rabs}+{1'b0,iabs};level=0;
 for(k=0;k<17;k=k+1)if(magnitude[k])level=(k+1)*12;
 bars_work[bin_index*8+:8]<=level;
 if(bin_index==15)state<=9;else begin bin_index<=bin_index+1'b1;state<=7;end
 end
 9:begin bars<=bars_work;frame_seq<=frame_seq+1'b1;state<=0;end
 endcase
 end end
endmodule
