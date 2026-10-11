`timescale 1ns/1ps
module audio_control #(parameter MEM_WORDS=32768)(
 (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 CLK CLK", X_INTERFACE_PARAMETER="XIL_INTERFACENAME CLK, ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET s_axi_aresetn" *) input wire s_axi_aclk,
 (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 RST RST", X_INTERFACE_PARAMETER="XIL_INTERFACENAME RST, POLARITY ACTIVE_LOW" *) input wire s_axi_aresetn,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWADDR", X_INTERFACE_PARAMETER="XIL_INTERFACENAME S_AXI, PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 18, READ_WRITE_MODE READ_WRITE" *) input wire [17:0] s_axi_awaddr,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *) input wire [2:0] s_axi_awprot,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *) input wire s_axi_awvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *) output wire s_axi_awready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WDATA" *) input wire [31:0] s_axi_wdata,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *) input wire [3:0] s_axi_wstrb,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WVALID" *) input wire s_axi_wvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI WREADY" *) output wire s_axi_wready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BRESP" *) output reg [1:0] s_axi_bresp,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BVALID" *) output reg s_axi_bvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI BREADY" *) input wire s_axi_bready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *) input wire [17:0] s_axi_araddr,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *) input wire [2:0] s_axi_arprot,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *) input wire s_axi_arvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *) output wire s_axi_arready,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RDATA" *) output reg [31:0] s_axi_rdata,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RRESP" *) output reg [1:0] s_axi_rresp,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RVALID" *) output reg s_axi_rvalid,
 (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 S_AXI RREADY" *) input wire s_axi_rready,
 input wire sample_valid,input wire [31:0] sample_pair,status,levels,diagnostics,target,
 output reg [31:0] gains,options,ui,
 output reg clear_clip,output wire [31:0] capture_status
);
 localparam AW=$clog2(MEM_WORDS);
 (* ram_style="block" *) reg [31:0] buffer[0:MEM_WORDS-1];
 reg [AW-1:0] wr_index;reg busy,done,stream_mode,overflow;
 reg [31:0] produced,consumed,frame_limit;
 reg have_aw,have_w,read_pending,read_mem;
 reg [17:0] aw_addr;reg [31:0] w_data,mem_q,reg_q;reg [3:0] w_strobe;reg [1:0] read_resp;
 wire write_commit=have_aw && have_w && !s_axi_bvalid;
 wire command=write_commit && aw_addr==18'h0000c && w_strobe[0];
 assign capture_status={produced[15:0],12'd0,stream_mode,overflow,done,busy};
 assign s_axi_awready=!have_aw && !s_axi_bvalid;
 assign s_axi_wready=!have_w && !s_axi_bvalid;
 assign s_axi_arready=!read_pending && !s_axi_rvalid;
 function [31:0] merged(input [31:0] old_value,new_value,input [3:0] strobe);
 integer k;begin merged=old_value;for(k=0;k<4;k=k+1)if(strobe[k])merged[k*8+:8]=new_value[k*8+:8];end endfunction
 always @(posedge s_axi_aclk)begin
  if(!s_axi_aresetn)begin
   gains<=32'h40404040;options<=32'h12800020;ui<=0;clear_clip<=0;
   have_aw<=0;have_w<=0;aw_addr<=0;w_data<=0;w_strobe<=0;
   s_axi_bvalid<=0;s_axi_bresp<=0;s_axi_rvalid<=0;s_axi_rdata<=0;s_axi_rresp<=0;
   read_pending<=0;read_mem<=0;read_resp<=0;reg_q<=0;mem_q<=0;
   wr_index<=0;produced<=0;consumed<=0;frame_limit<=MEM_WORDS;busy<=0;done<=0;stream_mode<=0;overflow<=0;
  end else begin
   clear_clip<=0;
   if(s_axi_awready && s_axi_awvalid)begin aw_addr<=s_axi_awaddr;have_aw<=1;end
   if(s_axi_wready && s_axi_wvalid)begin w_data<=s_axi_wdata;w_strobe<=s_axi_wstrb;have_w<=1;end
   if(s_axi_bvalid && s_axi_bready)s_axi_bvalid<=0;
   if(write_commit)begin
    have_aw<=0;have_w<=0;s_axi_bvalid<=1;s_axi_bresp<=0;
    case(aw_addr)
     18'h00000:gains<=merged(gains,w_data,w_strobe);
     18'h00004:options<=merged(options,w_data,w_strobe);
     18'h00008:ui<=merged(ui,w_data,w_strobe);
     18'h0000c:if(w_strobe[0] && w_data[2])clear_clip<=1;
     18'h0002c:consumed<=merged(consumed,w_data,w_strobe);
     18'h00030:if(!busy)frame_limit<=merged(frame_limit,w_data,w_strobe);
     default:s_axi_bresp<=2'b10;
    endcase
   end
   if(command && w_data[1])begin busy<=0;done<=0;produced<=0;consumed<=0;stream_mode<=0;overflow<=0;end
   else if(command && w_data[4])begin busy<=0;done<=1;end
   else if(command && w_data[0] && !busy)begin
    busy<=1;done<=0;produced<=0;consumed<=0;wr_index<=0;overflow<=0;
    stream_mode<=w_strobe[1] && w_data[8];
   end
   else if(sample_valid && busy)begin
    if(stream_mode && (produced-consumed)>=MEM_WORDS)begin
     overflow<=1;busy<=0;done<=0;
    end else begin
     buffer[wr_index]<=sample_pair;produced<=produced+1'b1;
     if((!stream_mode && wr_index==MEM_WORDS-1) || (stream_mode && produced+1'b1>=frame_limit))begin busy<=0;done<=1;end
     if(wr_index==MEM_WORDS-1)wr_index<=0;else wr_index<=wr_index+1'b1;
    end
   end
   if(s_axi_rvalid && s_axi_rready)s_axi_rvalid<=0;
   if(read_pending)begin
    s_axi_rvalid<=1;s_axi_rdata<=read_mem?mem_q:reg_q;s_axi_rresp<=read_resp;read_pending<=0;
   end
   if(s_axi_arready && s_axi_arvalid)begin
    read_pending<=1;read_mem<=0;read_resp<=0;reg_q<=0;
    if(s_axi_araddr[1:0]!=0)read_resp<=2'b10;
    else if(s_axi_araddr[17])begin
     if((s_axi_araddr[16:2])<MEM_WORDS)begin mem_q<=buffer[s_axi_araddr[AW+1:2]];read_mem<=1;end
     else read_resp<=2'b10;
    end else case(s_axi_araddr)
     18'h00000:reg_q<=gains;18'h00004:reg_q<=options;18'h00008:reg_q<=ui;
     18'h00010:reg_q<=capture_status;18'h00014:reg_q<=levels;18'h00018:reg_q<=diagnostics;
     18'h0001c:reg_q<=status;18'h00020:reg_q<=32'ha7010404;18'h00024:reg_q<=target;
     18'h00028:reg_q<=produced;18'h0002c:reg_q<=consumed;18'h00030:reg_q<=frame_limit;
     default:read_resp<=2'b10;
    endcase
   end
  end
 end
endmodule
