`timescale 1ns/1ps
module dashboard_text(input wire pixel_clk,reset,de,input wire [10:0] x,input wire [9:0] y,input wire [287:0] frame_data,
 output reg ink,output wire [23:0] color);
 integer ox,oy,sx,sy,scale,col,row;reg active,digit;reg [4:0] label_id,index;reg [7:0] character;reg [34:0] glyph;
 reg [3:0] decimal_digit;
 reg [7:0] character_q;reg [2:0] col_q,row_q;reg active_q;reg [23:0] color_q,next_color;
 assign color=color_q;
 always @*begin
 active=0;digit=0;ox=0;oy=0;label_id=0;scale=2;next_color=24'hcfeafa;
 if(y>=40&&y<54)begin
 if(x>=64&&x<352)begin active=1;ox=64;oy=40;label_id=0;end
 if(x>=400&&x<624)begin active=1;ox=400;oy=40;label_id=1;end
 if(x>=720&&x<976)begin active=1;ox=720;oy=40;label_id=24;next_color=(frame_data[63:62]!=0)?24'h32dda5:24'h607080;end
 end
 if(x>=64&&x<112)begin
 if(y>=82&&y<96)begin active=1;ox=64;oy=82;label_id=2;end
 if(y>=142&&y<156)begin active=1;ox=64;oy=142;label_id=3;end
 if(y>=202&&y<216)begin active=1;ox=64;oy=202;label_id=4;end
 if(y>=262&&y<276)begin active=1;ox=64;oy=262;label_id=5;end
 end
 if(x>=600&&x<696&&y>=88&&y<102)begin active=1;ox=600;oy=88;label_id=6;end
 if(x>=912&&x<1008&&y>=345&&y<359)begin active=1;ox=912;oy=345;label_id=7;end
 if(x>=600&&x<680&&y>=606&&y<620)begin active=1;ox=600;oy=606;label_id=8;end
 if(x>=304&&x<384&&y>=345&&y<359)begin active=1;ox=304;oy=345;label_id=9;end
 if(x>=960&&x<1248)begin
 if(y>=90&&y<104)begin active=1;ox=960;oy=90;label_id=10;end
 if(y>=200&&y<214)begin active=1;ox=960;oy=200;label_id=frame_data[136]?12:(frame_data[137]?13:11);end
 if(y>=245&&y<259)begin active=1;ox=960;oy=245;label_id=14;next_color=((|frame_data[132:128])||frame_data[158])?24'hff635e:24'h607080;end
 if(y>=415&&y<429)begin active=1;ox=960;oy=415;label_id=15;end
 end
 if(y>=676&&y<690)begin
 if(x>=64&&x<200)begin active=1;ox=64;oy=676;label_id=16;end
 if(x>=224&&x<360)begin active=1;ox=224;oy=676;label_id=17;end
 if(x>=384&&x<520)begin active=1;ox=384;oy=676;label_id=18;end
 if(x>=544&&x<680)begin active=1;ox=544;oy=676;label_id=19;end
 if(x>=704&&x<840)begin active=1;ox=704;oy=676;label_id=20;end
 if(x>=864&&x<1000)begin active=1;ox=864;oy=676;label_id=21;end
 if(x>=1024&&x<1160)begin active=1;ox=1024;oy=676;label_id=22;end
 if(x>=1184&&x<1250)begin active=1;ox=1184;oy=676;label_id=23;end
 end
 if(x>=960&&x<1056&&y>=125&&y<153)begin active=1;digit=1;ox=960;oy=125;scale=4;next_color=frame_data[108]?24'h32dda5:24'h607080;end
 sx=$signed({1'b0,x})-ox;sy=$signed({1'b0,y})-oy;
 if(scale==4)begin index=sx>>5;col=(sx>>2)&7;row=sy>>2;end
 else begin index=sx>>4;col=(sx>>1)&7;row=sy>>1;end
 character=8'd32;decimal_digit=0;
 case({label_id,index})
  10'd768:case(frame_data[63:62]) 0:character=8'd66;1:character=8'd66;2:character=8'd66;default:character=8'd66;endcase
  10'd769:case(frame_data[63:62]) 0:character=8'd65;1:character=8'd65;2:character=8'd65;default:character=8'd65;endcase
  10'd770:case(frame_data[63:62]) 0:character=8'd78;1:character=8'd78;2:character=8'd78;default:character=8'd78;endcase
  10'd771:case(frame_data[63:62]) 0:character=8'd68;1:character=8'd68;2:character=8'd68;default:character=8'd68;endcase
  10'd772:case(frame_data[63:62]) 0:character=8'd32;1:character=8'd32;2:character=8'd32;default:character=8'd32;endcase
  10'd773:case(frame_data[63:62]) 0:character=8'd79;1:character=8'd86;2:character=8'd87;default:character=8'd78;endcase
  10'd774:case(frame_data[63:62]) 0:character=8'd70;1:character=8'd79;2:character=8'd73;default:character=8'd65;endcase
  10'd775:case(frame_data[63:62]) 0:character=8'd70;1:character=8'd73;2:character=8'd78;default:character=8'd82;endcase
  10'd776:case(frame_data[63:62]) 0:character=8'd32;1:character=8'd67;2:character=8'd68;default:character=8'd82;endcase
  10'd777:case(frame_data[63:62]) 0:character=8'd32;1:character=8'd69;2:character=8'd32;default:character=8'd79;endcase
  10'd778:case(frame_data[63:62]) 0:character=8'd32;1:character=8'd32;2:character=8'd32;default:character=8'd87;endcase
  10'd320:character=8'd66;
  10'd321:character=8'd69;
  10'd322:character=8'd65;
  10'd323:character=8'd77;
  10'd325:character=8'd68;
  10'd326:character=8'd69;
  10'd327:character=8'd71;
  10'd0:character=8'd65;
  10'd1:character=8'd88;
  10'd2:character=8'd55;
  10'd3:character=8'd48;
  10'd4:character=8'd49;
  10'd5:character=8'd48;
  10'd7:character=8'd65;
  10'd8:character=8'd85;
  10'd9:character=8'd68;
  10'd10:character=8'd73;
  10'd11:character=8'd79;
  10'd13:character=8'd80;
  10'd14:character=8'd82;
  10'd15:character=8'd79;
  10'd32:character=8'd70;
  10'd33:character=8'd83;
  10'd35:character=8'd52;
  10'd36:character=8'd56;
  10'd37:character=8'd46;
  10'd38:character=8'd56;
  10'd39:character=8'd50;
  10'd40:character=8'd56;
  10'd41:character=8'd75;
  10'd64:character=8'd77;
  10'd65:character=8'd48;
  10'd96:character=8'd77;
  10'd97:character=8'd49;
  10'd128:character=8'd77;
  10'd129:character=8'd50;
  10'd160:character=8'd77;
  10'd161:character=8'd51;
  10'd192:character=8'd70;
  10'd193:character=8'd82;
  10'd194:character=8'd79;
  10'd195:character=8'd78;
  10'd196:character=8'd84;
  10'd224:character=8'd82;
  10'd225:character=8'd73;
  10'd226:character=8'd71;
  10'd227:character=8'd72;
  10'd228:character=8'd84;
  10'd256:character=8'd66;
  10'd257:character=8'd65;
  10'd258:character=8'd67;
  10'd259:character=8'd75;
  10'd288:character=8'd76;
  10'd289:character=8'd69;
  10'd290:character=8'd70;
  10'd291:character=8'd84;
  10'd352:character=8'd82;
  10'd353:character=8'd69;
  10'd354:character=8'd67;
  10'd356:character=8'd73;
  10'd357:character=8'd68;
  10'd358:character=8'd76;
  10'd359:character=8'd69;
  10'd384:character=8'd82;
  10'd385:character=8'd69;
  10'd386:character=8'd67;
  10'd388:character=8'd66;
  10'd389:character=8'd85;
  10'd390:character=8'd83;
  10'd391:character=8'd89;
  10'd416:character=8'd82;
  10'd417:character=8'd69;
  10'd418:character=8'd67;
  10'd420:character=8'd82;
  10'd421:character=8'd69;
  10'd422:character=8'd65;
  10'd423:character=8'd68;
  10'd424:character=8'd89;
  10'd448:character=8'd67;
  10'd449:character=8'd76;
  10'd450:character=8'd73;
  10'd451:character=8'd80;
  10'd480:character=8'd70;
  10'd481:character=8'd70;
  10'd482:character=8'd84;
  10'd484:character=8'd57;
  10'd485:character=8'd53;
  10'd486:character=8'd45;
  10'd487:character=8'd54;
  10'd488:character=8'd49;
  10'd489:character=8'd48;
  10'd490:character=8'd48;
  10'd491:character=8'd72;
  10'd492:character=8'd90;
  10'd512:character=8'd86;
  10'd513:character=8'd65;
  10'd514:character=8'd76;
  10'd515:character=8'd73;
  10'd516:character=8'd68;
  10'd544:character=8'd66;
  10'd545:character=8'd69;
  10'd546:character=8'd65;
  10'd547:character=8'd77;
  10'd576:character=8'd69;
  10'd577:character=8'd81;
  10'd608:character=8'd82;
  10'd609:character=8'd69;
  10'd610:character=8'd86;
  10'd611:character=8'd69;
  10'd612:character=8'd82;
  10'd613:character=8'd66;
  10'd640:character=8'd71;
  10'd641:character=8'd65;
  10'd642:character=8'd84;
  10'd643:character=8'd69;
  10'd672:character=8'd65;
  10'd673:character=8'd71;
  10'd674:character=8'd67;
  10'd704:character=8'd77;
  10'd705:character=8'd85;
  10'd706:character=8'd84;
  10'd707:character=8'd69;
  10'd736:character=8'd67;
  10'd737:character=8'd76;
  10'd738:character=8'd73;
  10'd739:character=8'd80;
 default:character=8'd32;
 endcase
 if(digit)begin
 case(index)0:decimal_digit=frame_data[107:104];1:decimal_digit=frame_data[103:100];2:decimal_digit=frame_data[99:96];default:decimal_digit=0;endcase
 character=frame_data[108]?(8'd48+decimal_digit):8'd45;
 end
 end
 always @(posedge pixel_clk)begin
  if(reset)begin character_q<=32;col_q<=0;row_q<=0;active_q<=0;color_q<=0;end
  else begin character_q<=character;col_q<=col;row_q<=row;
   active_q<=de && active && col>=0 && col<5 && row>=0 && row<7;color_q<=next_color;end
 end
 always @*begin
 case(character_q)
  8'd65:glyph=35'b01110100011000111111100011000110001;
  8'd66:glyph=35'b11110100011000111110100011000111110;
  8'd67:glyph=35'b01111100001000010000100001000001111;
  8'd68:glyph=35'b11110100011000110001100011000111110;
  8'd69:glyph=35'b11111100001000011110100001000011111;
  8'd70:glyph=35'b11111100001000011110100001000010000;
  8'd71:glyph=35'b01111100001000010111100011000101110;
  8'd72:glyph=35'b10001100011000111111100011000110001;
  8'd73:glyph=35'b11111001000010000100001000010011111;
  8'd74:glyph=35'b00111000100001000010100101001001100;
  8'd75:glyph=35'b10001100101010011000101001001010001;
  8'd76:glyph=35'b10000100001000010000100001000011111;
  8'd77:glyph=35'b10001110111010110101100011000110001;
  8'd78:glyph=35'b10001110011010110011100011000110001;
  8'd79:glyph=35'b01110100011000110001100011000101110;
  8'd80:glyph=35'b11110100011000111110100001000010000;
  8'd81:glyph=35'b01110100011000110001101011001001101;
  8'd82:glyph=35'b11110100011000111110101001001010001;
  8'd83:glyph=35'b01111100001000001110000010000111110;
  8'd84:glyph=35'b11111001000010000100001000010000100;
  8'd85:glyph=35'b10001100011000110001100011000101110;
  8'd86:glyph=35'b10001100011000110001100010101000100;
  8'd87:glyph=35'b10001100011000110101101011010101010;
  8'd88:glyph=35'b10001100010101000100010101000110001;
  8'd89:glyph=35'b10001100010101000100001000010000100;
  8'd90:glyph=35'b11111000010001000100010001000011111;
  8'd48:glyph=35'b01110100011001110101110011000101110;
  8'd49:glyph=35'b00100011000010000100001000010001110;
  8'd50:glyph=35'b01110100010000100010001000100011111;
  8'd51:glyph=35'b11110000010000101110000010000111110;
  8'd52:glyph=35'b00010001100101010010111110001000010;
  8'd53:glyph=35'b11111100001000011110000010000111110;
  8'd54:glyph=35'b01110100001000011110100011000101110;
  8'd55:glyph=35'b11111000010001000100010000100001000;
  8'd56:glyph=35'b01110100011000101110100011000101110;
  8'd57:glyph=35'b01110100011000101111000010000101110;
  8'd45:glyph=35'b00000000000000011111000000000000000;
  8'd46:glyph=35'b00000000000000000000000000011000110;
 default:glyph=0;
 endcase
 ink=active_q && glyph[34-row_q*5-col_q];
 end
endmodule
