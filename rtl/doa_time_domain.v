`timescale 1ns/1ps
// Clock-shared four-pair time-domain correlation baseline, not GCC-PHAT.
// Mic order: 0=(-x,-y), 1=(+x,-y), 2=(+x,+y), 3=(-x,+y).
// Correlate (0,1),(3,2),(0,3),(1,2), average parallel baselines.
// Continuous ping-pong capture; Q4 parabolic peak interpolation, no divider.
module doa_time_domain #(parameter FRAME=512, MAX_LAG=8, ENERGY_MIN=2097152)(
 input wire clk,rst,en,
 input wire signed [15:0] m0,m1,m2,m3,
 output reg signed [8:0] lag_x,lag_y,
 output reg valid,update, output reg [4:0] quality,
 output reg [7:0] frame_seq,output reg overrun
);
 localparam AW=$clog2(FRAME);
 (* ram_style="distributed" *) reg signed [15:0] mem0[0:2*FRAME-1],mem1[0:2*FRAME-1],mem2[0:2*FRAME-1],mem3[0:2*FRAME-1];
 reg [AW-1:0] wr,n;
 reg bank,readbank; reg [47:0] energy,block_energy;
 reg [2:0] state; reg [1:0] pair;
 reg signed [7:0] lag; reg [5:0] li,besti,qi;
 reg signed [47:0] acc,best;
 reg signed [47:0] scores[0:2*MAX_LAG];
 reg signed [8:0] delays[0:3];
 reg [3:0] good; reg [4:0] qmin;
 reg [51:0] remain,den; reg negfrac; reg [3:0] fraction;
 reg signed [15:0] a,b;
 integer idx;
 wire signed [31:0] prod=a*b;
 wire signed [47:0] total=acc+{{16{prod[31]}},prod};
 wire signed [31:0] energy_prod=m0*m0;
 always @* begin
  idx=$signed({1'b0,n})+$signed(lag);
  case(pair)
   0:begin a=mem0[{readbank,n}]; b=mem1[readbank*FRAME+idx];end
   1:begin a=mem3[{readbank,n}]; b=mem2[readbank*FRAME+idx];end
   2:begin a=mem0[{readbank,n}]; b=mem3[readbank*FRAME+idx];end
   default:begin a=mem1[{readbank,n}]; b=mem2[readbank*FRAME+idx];end
  endcase
 end
 always @(posedge clk) begin
  if(rst)begin
   wr<=0;bank<=0;energy<=0;block_energy<=0;state<=0;pair<=0;
   n<=MAX_LAG;lag<=-MAX_LAG;li<=0;acc<=0;best<=48'sh800000000000;besti<=0;
   good<=0;qmin<=31;lag_x<=0;lag_y<=0;valid<=0;update<=0;quality<=0;frame_seq<=0;overrun<=0;
   readbank<=0;qi<=0;remain<=0;den<=0;negfrac<=0;fraction<=0;
  end else begin
   update<=0;
   if(en)begin
    mem0[{bank,wr}]<=m0;mem1[{bank,wr}]<=m1;mem2[{bank,wr}]<=m2;mem3[{bank,wr}]<=m3;
    if(wr==FRAME-1)begin
     wr<=0;energy<=0;
     if(state==0)begin
      bank<=~bank;readbank<=bank;block_energy<=energy+{16'd0,energy_prod};state<=1;pair<=0;
      li<=0;lag<=-MAX_LAG;n<=MAX_LAG;acc<=0;best<=48'sh800000000000;besti<=0;good<=0;qmin<=31;
     end else overrun<=1;
    end else begin wr<=wr+1'b1;energy<=energy+{16'd0,energy_prod};end
   end
   case(state)
    1:begin
     if(n==FRAME-MAX_LAG-1)begin
      scores[li]<=total;
      if(total>best)begin best<=total;besti<=li;end
      acc<=0;n<=MAX_LAG;
      if(li==2*MAX_LAG)state<=2;
      else begin li<=li+1'b1;lag<=lag+1'b1;end
     end else begin acc<=total;n<=n+1'b1;end
    end
    2:begin : interpolation
     reg signed [51:0] curvature,numerator;
     reg [51:0] absc,absn;
     reg signed [8:0] integer_q4;
     integer_q4=($signed({1'b0,besti})-MAX_LAG)*16;
     delays[pair]<=integer_q4;
     good[pair]<=block_energy>=ENERGY_MIN && best>0 && besti>0 && besti<2*MAX_LAG;
     qi<=0;quality<=31;
     if(besti>0 && besti<2*MAX_LAG)begin
      curvature=scores[besti-1];curvature=curvature-2*$signed(best)+scores[besti+1];
      numerator=scores[besti-1];numerator=(numerator-scores[besti+1])*8;
      absc=curvature<0 ? -curvature:curvature;absn=numerator<0 ? -numerator:numerator;
      remain<=absn+(absc>>1);den<=absc;negfrac<=numerator>=0;fraction<=0;state<=3;
     end else state<=4;
    end
    3:begin
     if(den!=0 && remain>=den && fraction<8)begin remain<=remain-den;fraction<=fraction+1'b1;end
     else begin
      if(negfrac)delays[pair]<=delays[pair]-$signed({1'b0,fraction});
      else delays[pair]<=delays[pair]+$signed({1'b0,fraction});
      state<=4;
     end
    end
    4:begin : confidence_scan
     reg [4:0] candidate;
     candidate=31;
     // Peak must exceed every non-neighbour by at least 1/32 of its height.
     if((qi+1<besti || qi>besti+1) && scores[qi]>best-(best>>>5))begin
      good[pair]<=0;candidate=0;
     end
     if(candidate<qmin)qmin<=candidate;
     if(qi==2*MAX_LAG)begin
      if(pair==3)state<=5;
      else begin pair<=pair+1'b1;li<=0;lag<=-MAX_LAG;n<=MAX_LAG;acc<=0;best<=48'sh800000000000;besti<=0;state<=1;end
     end else qi<=qi+1'b1;
    end
    5:begin : publish
     reg signed [9:0] sx,sy;
     sx=$signed(delays[0]);sx=sx+$signed(delays[1]);
     sy=$signed(delays[2]);sy=sy+$signed(delays[3]);
     lag_x<=sx>>>1;lag_y<=sy>>>1;
     valid<=(&good) && ((delays[0]-delays[1])<=16) && ((delays[0]-delays[1])>=-16)
                    && ((delays[2]-delays[3])<=16) && ((delays[2]-delays[3])>=-16);
     quality<=(&good)?qmin:0;frame_seq<=frame_seq+1'b1;update<=1;state<=0;
    end
   endcase
  end
 end
endmodule
