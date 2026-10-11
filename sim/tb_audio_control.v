`timescale 1ns/1ps
module tb_audio_control;
 reg clk=0,rstn=0;always #10 clk=~clk;
 reg [17:0] awaddr=0,araddr=0;reg [31:0] wdata=0,pair=0;reg [3:0] strobe=0;
 reg awvalid=0,wvalid=0,bready=0,arvalid=0,rready=0,en=0;
 wire awready,wready,bvalid,arready,rvalid;wire [1:0] bresp,rresp;wire [31:0] rdata,gains,options,ui,cap;
 wire clear;reg [31:0] result;
 audio_control #(.MEM_WORDS(16)) dut(.s_axi_aclk(clk),.s_axi_aresetn(rstn),.s_axi_awaddr(awaddr),.s_axi_awprot(0),.s_axi_awvalid(awvalid),.s_axi_awready(awready),
 .s_axi_wdata(wdata),.s_axi_wstrb(strobe),.s_axi_wvalid(wvalid),.s_axi_wready(wready),.s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),
 .s_axi_araddr(araddr),.s_axi_arprot(0),.s_axi_arvalid(arvalid),.s_axi_arready(arready),.s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rvalid(rvalid),.s_axi_rready(rready),
 .sample_valid(en),.sample_pair(pair),.status(32'h12345678),.levels(32'h40302010),.diagnostics(32'h11223344),.target(32'h00000123),.gains(gains),.options(options),.ui(ui),.clear_clip(clear),.capture_status(cap));
 task write32(input [17:0] a,input [31:0] d,input [3:0] str,input integer skew,input [1:0] response);
 begin
 fork
 begin if(skew<0)repeat(-skew)@(negedge clk);@(negedge clk);awaddr=a;awvalid=1;do @(posedge clk);while(!awready);@(negedge clk);awvalid=0;end
 begin if(skew>0)repeat(skew)@(negedge clk);@(negedge clk);wdata=d;strobe=str;wvalid=1;do @(posedge clk);while(!wready);@(negedge clk);wvalid=0;end
 join
 wait(bvalid);if(bresp!==response)$fatal(1,"write response %b",bresp);
 repeat(3)begin @(negedge clk);if(!bvalid)$fatal(1,"B response dropped under backpressure");end
 bready=1;@(negedge clk);bready=0;
 end endtask
 task read32(input [17:0] a,input [31:0] expected,input [1:0] response);
 begin
 @(negedge clk);araddr=a;arvalid=1;do @(posedge clk);while(!arready);@(negedge clk);arvalid=0;
 wait(rvalid);if(rdata!==expected || rresp!==response)$fatal(1,"read addr %h got %h/%b expected %h/%b",a,rdata,rresp,expected,response);
 result=rdata;repeat(3)begin @(negedge clk);if(!rvalid || rdata!==result)$fatal(1,"R response unstable");end
 rready=1;@(negedge clk);rready=0;
 end endtask
 integer i;
 initial begin
 repeat(5)@(negedge clk);rstn=1;
 read32(0,32'h40404040,0);read32(32,32'ha7010404,0);read32(36,32'h123,0);
 write32(0,32'hffffffff,4'b0101,3,0);read32(0,32'h40ff40ff,0);
 write32(4,32'h01000001,15,-3,0);read32(4,32'h01000001,0);
 write32(12,1,1,0,0);
 for(i=0;i<16;i=i+1)begin @(negedge clk);pair=32'hab000000+i;en=1;@(negedge clk);en=0;end
 read32(16,32'h00100002,0);
 for(i=0;i<16;i=i+1)read32(18'h20000+4*i,32'hab000000+i,0);
 read32(18'h100,0,2);read32(18'h20001,0,2);write32(18'h20000,0,15,0,2);
 write32(12,1,1,1,0);write32(12,2,1,-1,0);read32(16,0,0);
 $display("TEST PASSED audio_control independent AW/W, stalls, byte enables, capture and abort");$finish;
 end
 initial begin #1000000;$fatal(1,"AXI timeout");end
endmodule
