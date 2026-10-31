// VISUAL mode 3 (WAVE): mirrored bottom PCM waveform, ported from the
// board-tested v0.26/v0.27 symmetric waveform (audio_ring_levels/overlay).
// 3.0 changes: dB height scale, analysis idles unless WAVE is shown,
// 64-slot history, registered PCM/level path, 7-clock pipelined renderer.

// Peak of max(|L|,|R|) per 32 accepted samples, written to a history ring.
// Each frame_start copies the newest BAR_COUNT entries to the display RAM:
// rise immediately, fall at most 3 steps per frame.
module audio_wave_levels #(parameter integer BAR_COUNT=40,LOG_SCALE=1)(
 input wire clk,rst,enable,frame_start,pcm_valid,
 input wire signed [15:0] pcm_left,pcm_right,
 input wire [5:0] bar_index,
 output wire [4:0] bar_height
);
 wire [15:0] left_abs=pcm_left[15]?(~pcm_left+16'd1):pcm_left;
 wire [15:0] right_abs=pcm_right[15]?(~pcm_right+16'd1):pcm_right;
 reg pcm_q,write_q;
 reg [15:0] magnitude_q,peak,final_peak;
 wire [15:0] next_peak=magnitude_q>peak?magnitude_q:peak;
 // LOG_SCALE: 1.5 dB per step, 1 at -42 dBFS, 28 from -1.2 dBFS.
 // Linear (v0.26): min(28, peak>>9), saturating at -7.2 dBFS.
 function [4:0] level;
  input [15:0] p;
  integer b;reg [3:0] msb;reg [1:0] mantissa;reg [5:0] l;
  begin
   msb=0;mantissa=0;
   if(p[1])begin msb=1;mantissa={p[0],1'b0};end
   for(b=2;b<16;b=b+1)if(p[b])begin msb=b;mantissa={p[b-1],p[b-2]};end
   l={msb,mantissa};
   if(LOG_SCALE)level=l>=59?5'd28:l>31?l-6'd31:5'd0;
   else level=p[15:9]>28?5'd28:p[13:9];
  end
 endfunction
 reg [4:0] sample_count;
 reg [5:0] write_pointer,history_count;
 reg [4:0] history[0:63]; /* fehdl force_ram=1, ram_style="bram" */
 // Two identically written RAMs: one read by the display, one by the
 // copy update. Entries written since enable form a prefix; others read 0.
 reg [4:0] display_heights[0:BAR_COUNT-1];
 reg [4:0] update_heights[0:BAR_COUNT-1];
 reg [5:0] filled;
 reg seen_sample;
 reg copying,copy_valid,copy_zero;
 reg [5:0] copy_pointer,copy_index,missing,result_index;
 reg [4:0] history_q;
 reg result_zero;
 wire [4:0] old_height=result_index<filled?update_heights[result_index]:5'd0;
 reg [4:0] new_height;
 assign bar_height=bar_index<filled?display_heights[bar_index]:5'd0;
 always @*begin
  if(!result_zero && history_q>=old_height)new_height=history_q;
  else if(old_height>3)begin
   if(!result_zero && history_q>old_height-5'd3)new_height=history_q;
   else new_height=old_height-5'd3;
  end else new_height=result_zero?5'd0:history_q;
 end
 always @(posedge clk)history_q<=history[copy_pointer];
 always @(posedge clk)if(write_q && !rst)history[write_pointer]<=level(final_peak);
 always @(posedge clk)begin
  if(copy_valid && !rst)begin
   display_heights[result_index]<=new_height;
   update_heights[result_index]<=new_height;
  end
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   pcm_q<=0;write_q<=0;magnitude_q<=0;peak<=0;final_peak<=0;
   sample_count<=0;write_pointer<=0;history_count<=0;seen_sample<=0;
   copying<=0;copy_valid<=0;copy_zero<=1;copy_pointer<=0;copy_index<=0;
   missing<=BAR_COUNT;result_index<=0;result_zero<=1;filled<=0;
  end else if(!enable)begin
   pcm_q<=0;write_q<=0;peak<=0;sample_count<=0;history_count<=0;seen_sample<=0;
   copying<=0;copy_valid<=0;filled<=0;
  end else begin
   pcm_q<=pcm_valid;
   magnitude_q<=left_abs>right_abs?left_abs:right_abs;
   write_q<=pcm_q && sample_count==31;
   if(write_q)begin
    write_pointer<=write_pointer+1'b1;
    if(history_count<BAR_COUNT)history_count<=history_count+1'b1;
   end
   if(pcm_q)begin
    seen_sample<=1;
    if(sample_count==31)begin final_peak<=next_peak;peak<=0;sample_count<=0;end
    else begin peak<=next_peak;sample_count<=sample_count+1'b1;end
   end
   if(frame_start)begin
    seen_sample<=pcm_q;
    copying<=1;copy_pointer<=write_pointer-BAR_COUNT;copy_index<=0;
    missing<=BAR_COUNT-history_count;copy_zero<=!seen_sample;
   end else if(copying)begin
    copy_pointer<=copy_pointer+1'b1;
    if(copy_index==BAR_COUNT-1)copying<=0;
    else copy_index<=copy_index+1'b1;
   end
   copy_valid<=copying;
   result_index<=copy_index;
   result_zero<=copy_zero || copy_index<missing;
   if(copy_valid && result_index==filled)filled<=filled+1'b1;
  end
 end
endmodule

// 80 slots of 8 px with 4 px ink over x=0..639 (VGA overlay coordinates).
// The two centre slots show the newest of 40 entries and age outwards.
// Band y=BAND_Y..BAND_Y+31, centre line between rows 15 and 16.
// Seven clocks, matching spectrum_renderer_pipeline.
module audio_wave_overlay #(parameter integer BAND_Y=448,WASH_LEVEL=2)(
 input wire clk,rst,de,enable,
 input wire [9:0] x,y,
 input wire [23:0] rgb_in,
 input wire [4:0] bar_height,
 output reg [5:0] bar_index,
 output reg [23:0] rgb_out
);
 wire [6:0] slot=x[9:3];
 wire [9:0] band_y=y-BAND_Y;
 reg [5:0] edge1;reg [3:0] row1,row2,row3;reg [2:0] col1,col2,col3;
 reg [3:0] wash1;reg visible1,visible2,visible3,visible4;
 // Outside the band wash1 is 0, so wash3/wash4 carry the untouched pixel.
 reg [23:0] rgb1,rgb2,result5,result6;
 reg [4:0] height2,weight2;
 reg [9:0] weighted3;
 reg [11:0] keep_r2,keep_g2,keep_b2,add_r2,add_g2,add_b2;
 reg [23:0] wash3,wash4;
 reg ink4;
 // Envelope weight round(2+14*cos^2(pi*e/80)), e = slots from the centre.
 reg [4:0] weight;
 always @*case(edge1)
  0,1,2,3,4:weight=16;5,6,7,8:weight=15;9,10,11:weight=14;
  12,13:weight=13;14,15:weight=12;16,17:weight=11;18,19:weight=10;
  20:weight=9;21,22:weight=8;23,24:weight=7;25,26:weight=6;
  27,28:weight=5;29,30,31:weight=4;32,33,34,35:weight=3;default:weight=2;
 endcase
 wire [3:0] half_height=weighted3[8:5]+4'd1;
 wire in_bar=row3<half_height;
 wire cap=row3==half_height-4'd1;
 wire ink=in_bar && (cap?col3>=3 && col3<5:col3>=2 && col3<6);
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   bar_index<=0;edge1<=0;row1<=0;row2<=0;row3<=0;col1<=0;col2<=0;col3<=0;wash1<=0;
   visible1<=0;visible2<=0;visible3<=0;visible4<=0;
   rgb1<=0;rgb2<=0;result5<=0;result6<=0;rgb_out<=0;
   height2<=0;weight2<=0;weighted3<=0;wash3<=0;wash4<=0;ink4<=0;
   keep_r2<=0;keep_g2<=0;keep_b2<=0;add_r2<=0;add_g2<=0;add_b2<=0;
  end else begin
   // 1: slot geometry; bar_index addresses the level RAM for stage 2.
   bar_index<=slot<40?slot[5:0]:7'd79-slot;
   edge1<=slot<40?7'd39-slot:slot-7'd40;
   row1<=band_y[4]?band_y[3:0]:4'd15-band_y[3:0];col1<=x[2:0];
   visible1<=enable && de && x<640 && y>=BAND_Y && y<BAND_Y+32;rgb1<=rgb_in;
   wash1<=enable && de && x<640 && y>=BAND_Y && y<BAND_Y+32?WASH_LEVEL+2+band_y[4:2]+band_y[4:3]:4'd0;
   // 2: level, envelope and blue-wash products.
   height2<=bar_height>28?5'd28:bar_height;weight2<=weight;
   keep_r2<=rgb1[23:16]*wash1;keep_g2<=rgb1[15:8]*wash1;keep_b2<=rgb1[7:0]*wash1;
   add_r2<=8'h3c*wash1;add_g2<=8'h82*wash1;add_b2<=8'hf0*wash1;
   row2<=row1;col2<=col1;visible2<=visible1;rgb2<=rgb1;
   // 3: rgb*(16-k)/16 + blue*k/16 per channel.
   weighted3<=height2*weight2;
   // Keep the photograph untouched behind the waveform; only the white bars
   // are overlaid.  The old blue wash made the entire bottom band visible.
   wash3<=rgb2;
   row3<=row2;col3<=col2;visible3<=visible2;
   // 4: half height floor(h*w/32)+1 per side, rounded cap row.
   ink4<=ink;wash4<=wash3;visible4<=visible3;
   // 5..7: white ink, else washed band (untouched photo outside it).
   result5<=visible4 && ink4?24'hffffff:wash4;
   result6<=result5;rgb_out<=result6;
  end
 end
endmodule
