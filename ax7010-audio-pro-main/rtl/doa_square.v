`timescale 1ns/1ps
// Compatibility shell: production 512-point GCC-PHAT; explicit legacy fallback.
module doa_square #(parameter FRAME=512, MAX_LAG=8, ENERGY_MIN=2097152,
 parameter GCC_PHAT=1, PHAT_EPSILON=64, PEAK_MIN=2048)(
 input wire clk,rst,en,input wire signed [15:0] m0,m1,m2,m3,
 output wire signed [8:0] lag_x,lag_y,output wire valid,update,
 output wire [4:0] quality,output wire [7:0] frame_seq,output wire overrun);
 generate if(GCC_PHAT)begin : gcc
 doa_gcc_phat #(.MAX_LAG(MAX_LAG),.ENERGY_MIN(ENERGY_MIN),.PHAT_EPSILON(PHAT_EPSILON),.PEAK_MIN(PEAK_MIN)) impl
 (clk,rst,en,m0,m1,m2,m3,lag_x,lag_y,valid,update,quality,frame_seq,overrun);
 // GCC engine is fixed at 512; reject accidental unsupported geometry in simulation.
 initial if(FRAME!=512 || MAX_LAG<1 || MAX_LAG>8 || PHAT_EPSILON<1) $error("Unsupported GCC-PHAT parameters");
 end else begin : legacy
 doa_time_domain #(.FRAME(FRAME),.MAX_LAG(MAX_LAG),.ENERGY_MIN(ENERGY_MIN)) impl
 (clk,rst,en,m0,m1,m2,m3,lag_x,lag_y,valid,update,quality,frame_seq,overrun);
 end endgenerate
endmodule
