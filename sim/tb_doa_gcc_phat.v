`timescale 1ns/1ps
module tb_doa_gcc_phat;
 reg clk=0,rst=1,en=0;always #10 clk=~clk;
 reg signed [15:0] m0=0,m1=0,m2=0,m3=0;
 wire signed [8:0] x,y,tx,ty;wire valid,update,overrun,accepted;wire [4:0] quality;wire [7:0] seq;
 doa_square dut(clk,rst,en,m0,m1,m2,m3,x,y,valid,update,quality,seq,overrun);
 direction_track track(clk,rst,update,valid,1'b1,3'd2,x,y,tx,ty,accepted);
 reg signed [15:0] data[0:4095],noise[0:4095];reg [31:0] seed=32'h76543210;
 integer i,k,fd,cycles=0,last_capture=0,latency;reg signed [8:0] oldx,oldy,oldtx,oldty;
 real az,faz;integer row=0;integer integer_peak[0:3];
 always @(negedge clk)if(!rst && dut.gcc.impl.state==16)integer_peak[dut.gcc.impl.pair]=dut.gcc.impl.besti-8;
 always @(posedge clk)begin
 cycles<=cycles+1;
 if(en && dut.gcc.impl.wr==511 && dut.gcc.impl.state==0)last_capture<=cycles;
 if(!rst && en && dut.gcc.impl.state!=0 && dut.gcc.impl.bank==dut.gcc.impl.readbank)$fatal(1,"capture writes locked bank");
 end
 function real angle(input integer a,b);
 real r;begin if(a==0 && b==0)angle=-1;else begin r=$atan2(-1.0*a,-1.0*b)*180.0/3.141592653589793;angle=r<0?r+360.0:r;end end
 endfunction
 task reset;
 begin @(negedge clk);rst=1;en=0;repeat(5)@(negedge clk);rst=0;end endtask
 task run_case(input integer dx,dy,mode,expect_valid,input integer exq,eyq);
 integer a,b,c,d,n,j;begin
 oldx=x;oldy=y;oldtx=tx;oldty=ty;
 for(j=0;j<512;j=j+1)begin
 i=64+j;if(mode==5)i=i+(row%20)*64;a=data[i];b=data[i-dx];c=data[i-dx-dy];d=data[i-dy];
 case(mode)
 1:begin b=b/2;c=c/2;end
 2:begin a=a+noise[i]/8;b=b+noise[i+600]/8;c=c+noise[i+1200]/8;d=d+noise[i+1800]/8;end
 3:begin a=a+data[i-13]/4;b=b+data[i-dx-17]/4;c=c+data[i-dx-dy-11]/4;d=d+data[i-dy-19]/4;end
 4:begin a=0;b=0;c=0;d=0;end
 5:begin a=noise[i];b=noise[i+600];c=noise[i+1200];d=noise[i+1800];end
 6:begin b=(7*data[i-dx]+data[i-dx-1])/8;c=(7*data[i-dx-dy]+data[i-dx-dy-1])/8;end
 9:begin a=a*4;b=b*4;c=c*4;d=d*4;end
 10:begin a=a/1024;b=b/1024;c=c/1024;d=d/1024;end
 11:begin a=7000;b=7000;c=7000;d=7000;end
 12:begin b=0;c=0;end
 7:begin b=(data[i-dx]+data[i-dx-1])/2;c=data[i-dx-dy-1];d=(data[i-dy]+data[i-dy-1])/2;end
 endcase
 @(negedge clk);en=1;m0=a;m1=b;m2=c;m3=d;
 @(negedge clk);en=0;if(j!=511)repeat(1022)@(negedge clk);
 end
 wait(update);#1;latency=cycles-last_capture;
 if(valid!==expect_valid)$fatal(1,"mode %0d expected valid=%0d got %0d x=%0d y=%0d",mode,expect_valid,valid,x,y);
 if(expect_valid && (x<exq-3 || x>exq+3 || y<eyq-3 || y>eyq+3))$fatal(1,"delay mismatch expected %0d,%0d got %0d,%0d",exq,eyq,x,y);
 if(!expect_valid && (x!==oldx || y!==oldy))$fatal(1,"invalid frame changed raw direction");
 if(expect_valid && exq%16==0 && eyq%16==0 && (integer_peak[0]!=exq/16 || integer_peak[1]!=exq/16 || integer_peak[2]!=eyq/16 || integer_peak[3]!=eyq/16))$fatal(1,"integer peak mismatch");
 if(overrun)$fatal(1,"normal-rate overrun");
 repeat(3)@(negedge clk);
 if(!accepted && (tx!==oldtx || ty!==oldty))$fatal(1,"invalid direction changed tracker");
 az=angle(x,y);faz=angle(tx,ty);
 $display("CASE %0d mode=%0d expected_q4=%0d,%0d actual_q4=%0d,%0d valid=%0d accepted=%0d angle=%0.3f filtered=%0.3f clocks=%0d int_pairs=%0d,%0d,%0d,%0d",row,mode,exq,eyq,x,y,valid,accepted,az,faz,latency,integer_peak[0],integer_peak[1],integer_peak[2],integer_peak[3]);
 $fdisplay(fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0.6f,%0.6f,%0d,%0d,%0d,%0d,%0d",row,mode,exq,eyq,x,y,valid,accepted,quality,az,faz,latency,integer_peak[0],integer_peak[1],integer_peak[2],integer_peak[3]);row=row+1;
 end endtask
 initial begin
 fd=$fopen("gcc_results.csv","w");$fdisplay(fd,"case,mode,expected_x_q4,expected_y_q4,x_q4,y_q4,valid,accepted,quality,angle,angle_filtered,compute_clocks,integer_pair01,integer_pair32,integer_pair03,integer_pair12");
 for(k=0;k<4096;k=k+1)begin
 seed={seed[30:0],seed[31]^seed[21]^seed[1]^seed[0]};data[k]=$signed(seed[15:0])>>>2;
 seed={seed[30:0],seed[31]^seed[21]^seed[1]^seed[0]};noise[k]=$signed(seed[15:0])>>>2;
 end
 reset;
 run_case(0,0,0,1,0,0);
 run_case(1,0,0,1,16,0);run_case(3,0,0,1,48,0);run_case(7,0,0,1,112,0);
 run_case(-1,0,0,1,-16,0);run_case(-3,0,0,1,-48,0);run_case(-7,0,0,1,-112,0);
 run_case(7,0,6,1,114,0);
 run_case(3,2,1,1,48,32);run_case(3,2,2,1,48,32);run_case(3,2,3,1,48,32);
 run_case(3,2,7,1,56,40);
 run_case(0,0,4,0,0,0);run_case(0,0,5,0,0,0);
 run_case(3,2,9,1,48,32);run_case(3,2,10,0,0,0);run_case(0,0,11,0,0,0);run_case(3,2,12,0,0,0);
 for(k=0;k<10;k=k+1)run_case(0,0,5,0,0,0);
 // Intentional producer overrun: finish 3 frames while the first is locked.
 reset;
 for(k=0;k<1536;k=k+1)begin
 i=64+(k%512);@(negedge clk);en=1;m0=data[i];m1=data[i-3];m2=data[i-5];m3=data[i-2];
 @(negedge clk);en=0;
 end
 wait(update);#1;if(!overrun || !valid || x<45 || x>51 || y<29 || y>35)$fatal(1,"locked buffer corrupted on overrun");
 $display("PASS intentional overrun: first frame preserved, later frames dropped");
 $fclose(fd);$display("TEST PASSED doa_gcc_phat");$finish;
 end
 initial begin #500000000;$fatal(1,"GCC timeout");end
endmodule
