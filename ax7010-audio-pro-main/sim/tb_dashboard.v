`timescale 1ns/1ps
module tb_dashboard;
reg clk=0,rst=1,de=1;always #5 clk=~clk;reg [10:0] x;reg [9:0] y;reg [287:0] data=0;wire [23:0] rgb;
integer fd,ix,iy,i;
audio_dashboard dut(clk,rst,x,y,de,data,rgb);
initial begin
 data[8:0]=-81;data[17:9]=-81;data[18]=1;
 data[48:40]=-81;data[57:49]=-81;data[36]=1;data[35]=1;data[58]=1;data[61]=1;
 data[95:64]=32'h7398c0b0;data[127:96]=32'h1045;
 data[137]=1;data[63:62]=2; 
 for(i=0;i<16;i=i+1)data[160+i*8+:8]=40+((i*31)%160);
 repeat(2)@(negedge clk);rst=0;
 fd=$fopen("dashboard.ppm","w");$fwrite(fd,"P3\n1280 720\n255\n");
 for(iy=0;iy<720;iy=iy+1)begin
  for(ix=0;ix<1280;ix=ix+1)begin
   @(negedge clk);x=ix;y=iy;@(posedge clk);#1;
   if((^rgb)===1'bx)$fatal(1,"unknown RGB at %d,%d",ix,iy);
   $fwrite(fd,"%0d %0d %0d ",rgb[23:16],rgb[15:8],rgb[7:0]);
  end
  $fwrite(fd,"\n");
 end
 $fclose(fd);$display("DASHBOARD TEST PASSED");$finish;
end
endmodule
