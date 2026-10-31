// Bottom PCM history bars, mirrored about a centre line with a blue wash.
// Preserve the established two-clock video latency and module interface.
module audio_ring_overlay #(
 parameter integer ENABLE=1
)(
 input wire clk,rst,hs,vs,de,enable,
 input wire [9:0] pixel_x,
 input wire [8:0] pixel_y,
 input wire [23:0] rgb_in,
 input wire [4:0] bar_height,
 output wire [6:0] bar_index,
 output reg hs_out,vs_out,de_out,
 output reg [9:0] x_out,
 output reg [23:0] rgb_out,
 input wire [1:0] wash_level // v0.27 panel: wash base k=2+level, 2 is the v0.26 look
);
 // 80 slots of 8px, 4px ink. The two centre slots show the newest of 40
 // history entries and age outwards. Band y=448..479, centre between
 // 463/464; the publicity subtitle band ends at y=443.
 reg [6:0] index_q;
 reg [5:0] edge_q;
 reg [3:0] row_q;
 reg [2:0] col_q;
 reg [3:0] wash_q;
 reg visible_q,hs_q,vs_q,de_q;
 reg [9:0] x_q;
 reg [23:0] rgb_q;
 wire [6:0] slot=pixel_x[9:3];
 wire [8:0] band_y=pixel_y-9'd448;
 // Envelope weight 2+14*cos^2(pi*e/80), e = slots from the centre.
 reg [4:0] weight;
 always @* case(edge_q)
  0,1,2,3,4: weight=16; 5,6,7,8: weight=15; 9,10,11: weight=14;
  12,13: weight=13; 14,15: weight=12; 16,17: weight=11; 18,19: weight=10;
  20: weight=9; 21,22: weight=8; 23,24: weight=7; 25,26: weight=6;
  27,28: weight=5; 29,30,31: weight=4; 32,33,34,35: weight=3; default: weight=2;
 endcase
 wire [4:0] limited_height=bar_height>28 ? 5'd28 : bar_height;
 wire [9:0] weighted=limited_height*weight;
 wire [3:0] half_height=weighted[8:5]+4'd1;
 wire in_bar=row_q<half_height;
 wire cap=row_q==half_height-4'd1;
 wire ink=in_bar && (cap ? col_q>=3 && col_q<5 : col_q>=2 && col_q<6);
 // rgb*(16-k)/16 + blue*k/16 per channel, k=base..base+10 deepening downwards.
 function [7:0] wash(input [7:0] c,input [7:0] blue,input [3:0] k);
  reg [11:0] keep,add;
  begin keep=c*k;add=blue*k;wash=c-keep[11:4]+add[11:4];end
 endfunction
 assign bar_index=index_q;
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   index_q<=0;edge_q<=0;row_q<=0;col_q<=0;wash_q<=0;visible_q<=0;
   hs_q<=1;vs_q<=1;de_q<=0;x_q<=0;rgb_q<=0;
   hs_out<=1;vs_out<=1;de_out<=0;x_out<=0;rgb_out<=0;
  end else begin
   index_q<=slot<40 ? slot : 7'd79-slot;
   edge_q<=slot<40 ? 7'd39-slot : slot-7'd40;
   row_q<=band_y[4] ? band_y[3:0] : 4'd15-band_y[3:0];
   col_q<=pixel_x[2:0];wash_q<={2'd0,wash_level}+4'd2+band_y[4:2]+band_y[4:3];
   visible_q<=ENABLE && enable && de && pixel_x<640 && pixel_y>=448 && pixel_y<480;
   hs_q<=hs;vs_q<=vs;de_q<=de;x_q<=pixel_x;rgb_q<=rgb_in;
   hs_out<=hs_q;vs_out<=vs_q;de_out<=de_q;x_out<=x_q;
   if(visible_q && ink) rgb_out<=24'hffffff;
   else if(visible_q) rgb_out<={wash(rgb_q[23:16],8'h3c,wash_q),
                                wash(rgb_q[15:8],8'h82,wash_q),wash(rgb_q[7:0],8'hf0,wash_q)};
   else rgb_out<=rgb_q;
  end
 end
endmodule
