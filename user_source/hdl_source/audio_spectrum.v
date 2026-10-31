// 16-bin, 512-sample real DFT @ 48 kHz; bins 93.75 .. 1500 Hz.
// Triangular window, shared arithmetic, attack/decay, frame-atomic display.
// Input is selected test/SD music PCM before the mixer; click sound is excluded.
module audio_spectrum(input clk,rst,frame_start,de,
 input [23:0] rgb_in,input [9:0] x,y,input [1:0] mode,input music_enable,
 input pcm_valid,input signed [15:0] pcm_left,output [23:0] rgb_out,
 input [9:0] xga_x,xga_y);
function signed [8:0] sine;
 input [8:0] phase;
 reg [6:0] addr;reg [7:0] q;
 begin
 addr=phase[7]?7'd127-phase[6:0]:phase[6:0];
 case(addr)
 7'd0:q=8'd1;
7'd1:q=8'd2;
7'd2:q=8'd4;
7'd3:q=8'd5;
7'd4:q=8'd7;
7'd5:q=8'd9;
7'd6:q=8'd10;
7'd7:q=8'd12;
7'd8:q=8'd13;
7'd9:q=8'd15;
7'd10:q=8'd16;
7'd11:q=8'd18;
7'd12:q=8'd19;
7'd13:q=8'd21;
7'd14:q=8'd22;
7'd15:q=8'd24;
7'd16:q=8'd26;
7'd17:q=8'd27;
7'd18:q=8'd29;
7'd19:q=8'd30;
7'd20:q=8'd32;
7'd21:q=8'd33;
7'd22:q=8'd35;
7'd23:q=8'd36;
7'd24:q=8'd38;
7'd25:q=8'd39;
7'd26:q=8'd41;
7'd27:q=8'd42;
7'd28:q=8'd44;
7'd29:q=8'd45;
7'd30:q=8'd46;
7'd31:q=8'd48;
7'd32:q=8'd49;
7'd33:q=8'd51;
7'd34:q=8'd52;
7'd35:q=8'd54;
7'd36:q=8'd55;
7'd37:q=8'd56;
7'd38:q=8'd58;
7'd39:q=8'd59;
7'd40:q=8'd61;
7'd41:q=8'd62;
7'd42:q=8'd63;
7'd43:q=8'd65;
7'd44:q=8'd66;
7'd45:q=8'd67;
7'd46:q=8'd69;
7'd47:q=8'd70;
7'd48:q=8'd71;
7'd49:q=8'd72;
7'd50:q=8'd74;
7'd51:q=8'd75;
7'd52:q=8'd76;
7'd53:q=8'd78;
7'd54:q=8'd79;
7'd55:q=8'd80;
7'd56:q=8'd81;
7'd57:q=8'd82;
7'd58:q=8'd84;
7'd59:q=8'd85;
7'd60:q=8'd86;
7'd61:q=8'd87;
7'd62:q=8'd88;
7'd63:q=8'd89;
7'd64:q=8'd90;
7'd65:q=8'd91;
7'd66:q=8'd93;
7'd67:q=8'd94;
7'd68:q=8'd95;
7'd69:q=8'd96;
7'd70:q=8'd97;
7'd71:q=8'd98;
7'd72:q=8'd99;
7'd73:q=8'd100;
7'd74:q=8'd101;
7'd75:q=8'd102;
7'd76:q=8'd102;
7'd77:q=8'd103;
7'd78:q=8'd104;
7'd79:q=8'd105;
7'd80:q=8'd106;
7'd81:q=8'd107;
7'd82:q=8'd108;
7'd83:q=8'd109;
7'd84:q=8'd109;
7'd85:q=8'd110;
7'd86:q=8'd111;
7'd87:q=8'd112;
7'd88:q=8'd112;
7'd89:q=8'd113;
7'd90:q=8'd114;
7'd91:q=8'd114;
7'd92:q=8'd115;
7'd93:q=8'd116;
7'd94:q=8'd116;
7'd95:q=8'd117;
7'd96:q=8'd118;
7'd97:q=8'd118;
7'd98:q=8'd119;
7'd99:q=8'd119;
7'd100:q=8'd120;
7'd101:q=8'd120;
7'd102:q=8'd121;
7'd103:q=8'd121;
7'd104:q=8'd122;
7'd105:q=8'd122;
7'd106:q=8'd123;
7'd107:q=8'd123;
7'd108:q=8'd123;
7'd109:q=8'd124;
7'd110:q=8'd124;
7'd111:q=8'd124;
7'd112:q=8'd125;
7'd113:q=8'd125;
7'd114:q=8'd125;
7'd115:q=8'd126;
7'd116:q=8'd126;
7'd117:q=8'd126;
7'd118:q=8'd126;
7'd119:q=8'd126;
7'd120:q=8'd126;
7'd121:q=8'd127;
7'd122:q=8'd127;
7'd123:q=8'd127;
7'd124:q=8'd127;
7'd125:q=8'd127;
7'd126:q=8'd127;
7'd127:q=8'd127;
 endcase
 sine=phase[8]?-$signed({1'b0,q}):$signed({1'b0,q});
 end
endfunction
reg [2:0] state;
reg [8:0] sample_n,angle;
reg [3:0] bin;
reg signed [21:0] window_product;
reg signed [11:0] windowed;
wire [7:0] window_weight=sample_n[8]?8'd255-sample_n[7:0]:sample_n[7:0];
reg signed [20:0] prod_r,prod_i;
// 3.0 area: accumulators in block RAM (one write, one registered read).
reg signed [31:0] acc_r[0:15]; /* fehdl force_ram=1, ram_style="bram" */
reg signed [31:0] acc_i[0:15]; /* fehdl force_ram=1, ram_style="bram" */
reg signed [31:0] sum_r,sum_i;
reg signed [31:0] acc_r_q,acc_i_q;
// Each bin is overwritten on sample zero; no RAM reset or read-before-write.
// The bin address is stable through multiply states before this data is used.
always @(posedge clk)begin
 acc_r_q<=acc_r[bin];acc_i_q<=acc_i[bin];
 if(state==4 && music_enable && !rst)begin
  acc_r[bin]<=sum_r;acc_i[bin]<=sum_i;
 end
end
// Final-sample level update in three registered steps (3.0 timing):
// |re|,|im| -> |re|+|im| clamp -> attack/decay write, one bin per clock.
wire [31:0] abs_r=sum_r[31]?-sum_r:sum_r;
wire [31:0] abs_i=sum_i[31]?-sum_i:sum_i;
reg [31:0] abs_r_q,abs_i_q;
wire [32:0] magnitude={1'b0,abs_r_q}+{1'b0,abs_i_q};
wire [6:0] target_level=magnitude[32:16]>96?7'd96:magnitude[22:16];
reg [6:0] target_q;reg [3:0] bin_abs,bin_target;reg update_abs,update_target;
reg [6:0] levels[0:15],shown[0:15],peaks[0:15];
// 3.0 area: one sine lookup (cos in state 2, sin in state 5) and one
// shown/peak update per clock for 16 clocks after frame_start (blanking).
reg signed [8:0] cos_q;
wire [8:0] sine_phase=state==2?angle+9'd128:angle;
wire signed [8:0] sine_q=sine(sine_phase);
reg [4:0] show_step;
wire [3:0] show_bin=show_step[3:0];
integer i;
always @(posedge clk or posedge rst)begin
 if(rst)begin
  state<=0;sample_n<=0;angle<=0;bin<=0;window_product<=0;windowed<=0;
  prod_r<=0;prod_i<=0;sum_r<=0;sum_i<=0;
  abs_r_q<=0;abs_i_q<=0;target_q<=0;bin_abs<=0;bin_target<=0;update_abs<=0;update_target<=0;
  cos_q<=0;show_step<=16;
  for(i=0;i<16;i=i+1)begin levels[i]<=0;shown[i]<=0;peaks[i]<=0;end
 end else begin
  abs_r_q<=abs_r;abs_i_q<=abs_i;bin_abs<=bin;update_abs<=music_enable && state==4 && sample_n==511;
  target_q<=target_level;bin_target<=bin_abs;update_target<=music_enable && update_abs;
  if(!music_enable)begin
   state<=0;sample_n<=0;show_step<=16;
   for(i=0;i<16;i=i+1)begin levels[i]<=0;shown[i]<=0;peaks[i]<=0;end
  end else begin
   if(frame_start)show_step<=0;
   else if(!show_step[4])begin
    shown[show_bin]<=levels[show_bin];
    peaks[show_bin]<=levels[show_bin]>=peaks[show_bin]?levels[show_bin]:
     peaks[show_bin]!=0?peaks[show_bin]-1'b1:7'd0;
    show_step<=show_step+1'b1;
   end
   if(update_target)levels[bin_target]<=target_q>=levels[bin_target]?target_q:
     levels[bin_target]>2 && target_q<levels[bin_target]-2?levels[bin_target]-2:target_q;
   case(state)
    0:if(pcm_valid)begin
     window_product<= $signed(pcm_left[15:4])*$signed({1'b0,window_weight});
     bin<=0;angle<=sample_n;state<=1;
    end
    1:begin windowed<=window_product>>>8;state<=2;end
    2:begin cos_q<=sine_q;state<=5;end
    5:begin prod_r<=windowed*cos_q;prod_i<=windowed*sine_q;state<=3;end
    3:begin
     sum_r<=sample_n==0?{{11{prod_r[20]}},prod_r}:acc_r_q+{{11{prod_r[20]}},prod_r};
     sum_i<=sample_n==0?{{11{prod_i[20]}},prod_i}:acc_i_q+{{11{prod_i[20]}},prod_i};state<=4;
    end
    4:begin
     if(bin==15)begin sample_n<=sample_n+1'b1;state<=0;end
     else begin bin<=bin+1'b1;angle<=angle+sample_n;state<=2;end
    end
    default:state<=0;
   endcase
  end
 end
end
// BARS: 32 bodies at 12-pixel pitch in 640x480 overlay space (x, y), 16 bands.
// RADIAL: 48-sector ring drawn in native XGA space (xga_x, xga_y).
wire [111:0] heights,peak_values;
genvar b;
for(b=0;b<16;b=b+1)begin: bundle
 assign heights[b*7+:7]=shown[b];
 assign peak_values[b*7+:7]=peaks[b];
end
spectrum_renderer_pipeline renderer(clk,rst,de,rgb_in,x,y,xga_x,xga_y,mode,music_enable,heights,peak_values,rgb_out);
endmodule

// Seven pixel clocks.
// RADIAL is antialiased with signed distances, in 1/8-pixel coverage steps:
//  - outer arc: 8d = 4(R^2-r^2)/R = (R^2-r^2)*(65536/R) >> 14, one small
//    multiply with a per-band reciprocal; inner arc (R=45): constant compares;
//  - sector gaps: perpendicular distance to the nearest 7.5-degree spoke,
//    s_k = minor*cos(k*7.5) - major*sin(k*7.5) in 1/256 px within an octant;
// coverage = min(outer, inner, gap) blends a smooth radial gradient over
// the photo. BARS keep the original 640x480 geometry and colours.
module spectrum_renderer_pipeline(input clk,rst,de,input [23:0] rgb_in,
 input [9:0] x,y,xga_x,xga_y,input [1:0] mode,input music_enable,
 input [111:0] heights,peak_values,output reg [23:0] rgb_out);
localparam [9:0] CX=884,CY=628;      // 1.6 x the 640x480 centre (552,392)
localparam [9:0] BOX=96;             // |dx|,|dy| bound, > R_MAX + 1
localparam [6:0] R_BASE=54;          // R = 54 + 3h/8 -> 54..90 px
localparam [14:0] R_IN2=2025;        // inner radius 45 px
localparam [7:0] R_IN=45;
localparam signed [17:0] HALF_GAP=192; // 0.75 px -> 1.5 px gaps
// Number of k=1..8 with v >= (k-4)*step: 1/8 coverage of v = 4*d*step.
function [3:0] cover8;input signed [19:0] v;input [7:0] step;integer k;begin
 cover8=0;for(k=1;k<=8;k=k+1)if(v>=(k-4)*$signed({1'b0,step}))cover8=cover8+1'b1;
end endfunction
function [3:0] min3;input [3:0] a,b,c;begin
 min3=a<b?a:b;if(c<min3)min3=c;
end endfunction
function [7:0] blend;input [7:0] bg,fg;input [3:0] a;reg signed [13:0] p,q;begin
 p=($signed({1'b0,fg})-$signed({1'b0,bg}))*$signed({1'b0,a});q=p>>>3;blend=bg+q;
end endfunction
function [14:0] mul7x8;input [6:0] a;input [7:0] b;begin mul7x8=a*b;end endfunction
function [13:0] mul7x7;input [6:0] a,b;begin mul7x7=a*b;end endfunction
// round(65536/R) for the outer radii 54..90.
function [10:0] inv_r;input [6:0] R;begin
 case(R)54:inv_r=1214;55:inv_r=1192;56:inv_r=1170;57:inv_r=1150;58:inv_r=1130;59:inv_r=1111;60:inv_r=1092;61:inv_r=1074;62:inv_r=1057;63:inv_r=1040;64:inv_r=1024;65:inv_r=1008;66:inv_r=993;67:inv_r=978;68:inv_r=964;69:inv_r=950;70:inv_r=936;71:inv_r=923;72:inv_r=910;73:inv_r=898;74:inv_r=886;75:inv_r=874;76:inv_r=862;77:inv_r=851;78:inv_r=840;79:inv_r=830;80:inv_r=819;81:inv_r=809;82:inv_r=799;83:inv_r=790;84:inv_r=780;85:inv_r=771;86:inv_r=762;87:inv_r=753;88:inv_r=745;89:inv_r=736;90:inv_r=728;default:inv_r=0;endcase
end endfunction
// base + t*delta/128 for t = 0..95 (delta scaled so t=95 reaches the outer colour).
function [7:0] shade;input [7:0] base;input [6:0] t;input [7:0] delta;reg [14:0] m;begin
 m=mul7x8(t,delta);shade=base+m[14:7];
end endfunction
reg [23:0] rgb[0:5];reg [9:0] xx[0:4],yy[0:4];reg [1:0] md[0:5];reg [5:0] enable;
// BARS
reg [3:0] band2;reg [6:0] height3,peak3,height4,peak4;
reg body5,cap5,base5;reg [23:0] bar_color5;
wire [8:0] bx=xx[1]-9'd128;
// RADIAL, numbered by the clock edge that writes them.
reg [9:0] ax1,ay1;reg right1,bottom1;
reg [6:0] major2,minor2;reg [14:0] r2_2;reg in2,swap2,right2,bottom2;
reg signed [17:0] s3[1:5];reg [15:0] m3,d3;reg [14:0] r2_3;reg in3,swap3,right3,bottom3;
reg [3:0] sector4;reg signed [17:0] dist4;reg [14:0] r2_4;reg in4;
reg [6:0] t5;reg signed [8:0] delta5;reg [10:0] inv5;reg [3:0] gap5,inner5;reg in5;
reg signed [19:0] outer_p;reg signed [5:0] outer_k;reg [3:0] outer6;
reg [3:0] alpha6;reg [23:0] ring_color6;
// Per-band outer radius R = 54 + 3h/8 and R^2, refreshed one band per clock
// in two registered steps; heights only change in vertical blanking.
// No reset: the table is rewritten every 16 clocks, so it maps to
// distributed RAM instead of flip-flops. Entry = {R^2, 65536/R}.
reg [24:0] R_tab[0:15];reg [3:0] tab_k,tab_k1;reg [6:0] tab_R;
wire [6:0] tab_h=heights[tab_k*7+:7];
always @(posedge clk)R_tab[tab_k1]<={mul7x7(tab_R,tab_R),inv_r(tab_R)};
wire [24:0] tab4=R_tab[sector4];
wire signed [15:0] delta4=$signed({2'b0,tab4[24:11]})-$signed({1'b0,r2_4});
// Octant spokes 7.5..37.5 degrees: 256*cos, 256*sin.
function [7:0] spoke_cos;input [2:0] k;begin
 case(k)1:spoke_cos=254;2:spoke_cos=247;3:spoke_cos=237;4:spoke_cos=222;default:spoke_cos=203;endcase
end endfunction
function [7:0] spoke_sin;input [2:0] k;begin
 case(k)1:spoke_sin=33;2:spoke_sin=66;3:spoke_sin=98;4:spoke_sin=128;default:spoke_sin=156;endcase
end endfunction
reg signed [17:0] s2[1:5];reg [2:0] o3;
reg [3:0] quadrant;reg [5:0] sector;reg signed [17:0] lo3,hi3;
reg [14:0] t_r2;reg [6:0] t4;
integer i;
always @*begin
 // Edge 3 inputs: signed spoke distances.
 for(i=1;i<=5;i=i+1)
  s2[i]=$signed({3'b0,mul7x8(minor2,spoke_cos(i))})-$signed({3'b0,mul7x8(major2,spoke_sin(i))});
 // Edge 4 inputs: o3 = cells passed in the octant, 48-cell sector,
 // nearest-spoke distance.
 o3=0;for(i=1;i<=5;i=i+1)if(!s3[i][17])o3=o3+1'b1;
 quadrant=swap3?4'd11-o3:{1'b0,o3};
 sector=right3?(bottom3?{2'b0,quadrant}:6'd47-quadrant):
               (bottom3?6'd23-quadrant:6'd24+quadrant);
 lo3=o3==0?$signed({2'b0,m3}):s3[o3];
 hi3=o3==5?$signed({2'b0,d3}):-s3[o3+1];
 // Edge 5 inputs: gradient position over r = 45..90 (r^2 scale, 0..95).
 t_r2=r2_4-R_IN2;
 t4=r2_4<R_IN2 ? 7'd0 : t_r2>=15'd6080 ? 7'd95 : t_r2[12:6];
 // Edge 6 input: outer-arc coverage in eighths, clamp(floor(8d)+4, 0, 8).
 outer_p=delta5*$signed({1'b0,inv5});outer_k=(outer_p>>>14)+4;
 outer6=outer_k[5]?4'd0:outer_k>8?4'd8:outer_k[3:0];
end
always @(posedge clk or posedge rst)begin
 if(rst)begin
  for(i=0;i<6;i=i+1)begin rgb[i]<=0;md[i]<=0;end
  for(i=0;i<5;i=i+1)begin xx[i]<=0;yy[i]<=0;end
  for(i=1;i<=5;i=i+1)s3[i]<=0;
  tab_k<=0;tab_k1<=0;tab_R<=0;
  enable<=0;rgb_out<=0;band2<=0;height3<=0;peak3<=0;height4<=0;peak4<=0;
  body5<=0;cap5<=0;base5<=0;bar_color5<=0;
  ax1<=0;ay1<=0;right1<=0;bottom1<=0;major2<=0;minor2<=0;r2_2<=0;in2<=0;swap2<=0;right2<=0;bottom2<=0;
  m3<=0;d3<=0;r2_3<=0;in3<=0;swap3<=0;right3<=0;bottom3<=0;
  sector4<=0;dist4<=0;r2_4<=0;in4<=0;t5<=0;delta5<=0;inv5<=0;gap5<=0;inner5<=0;in5<=0;alpha6<=0;ring_color6<=0;
 end else begin
  rgb[0]<=rgb_in;xx[0]<=x;yy[0]<=y;md[0]<=mode;
  enable<={enable[4:0],de && music_enable && mode!=0};
  for(i=1;i<6;i=i+1)begin rgb[i]<=rgb[i-1];md[i]<=md[i-1];end
  for(i=1;i<5;i=i+1)begin xx[i]<=xx[i-1];yy[i]<=yy[i-1];end
  // BARS (edges 3..6)
  band2<=bx/24;
  height3<=heights[band2*7+:7]/3;peak3<=peak_values[band2*7+:7]/3;
  height4<=height3;peak4<=peak3;
  body5<=0;cap5<=0;base5<=0;
  bar_color5<={8'd24+8'd200-yy[4][7:0],8'd132+8'd200-yy[4][7:0],8'hff};
  if(md[4]==1 && xx[4]>=128 && xx[4]<512 && yy[4]>=416 && yy[4]<465 &&
     ((xx[4]-128)%12)>=2 && ((xx[4]-128)%12)<10)begin
   body5<=height4!=0 && yy[4]<456 && yy[4]>=456-height4;
   cap5<=peak4!=0 && yy[4]>=454-peak4 && yy[4]<456-peak4;
   base5<=yy[4]==456;
  end
  tab_k<=tab_k+1'b1;tab_k1<=tab_k;tab_R<=R_BASE+(({2'b0,tab_h}+{1'b0,tab_h,1'b0})>>3);
  // RADIAL (edges 1..6)
  ax1<=xga_x>=CX?xga_x-CX:CX-xga_x;ay1<=xga_y>=CY?xga_y-CY:CY-xga_y;
  right1<=xga_x>=CX;bottom1<=xga_y>=CY;
  in2<=ax1<BOX && ay1<BOX;swap2<=ax1<ay1;right2<=right1;bottom2<=bottom1;
  major2<=ax1>=ay1?ax1[6:0]:ay1[6:0];minor2<=ax1>=ay1?ay1[6:0]:ax1[6:0];
  r2_2<=ax1[6:0]*ax1[6:0]+ay1[6:0]*ay1[6:0];
  for(i=1;i<=5;i=i+1)s3[i]<=s2[i];
  m3<={1'b0,minor2,8'd0};d3<=(major2-minor2)*8'd181;
  r2_3<=r2_2;in3<=in2;swap3<=swap2;right3<=right2;bottom3<=bottom2;
  sector4<=sector[3:0];dist4<=lo3<hi3?lo3:hi3;r2_4<=r2_3;in4<=in3;
  // |R^2-r^2| > 128 >= R is fully inside or outside: saturate to 9 bits.
  delta5<=delta4>127?9'sd127:delta4<-128?-9'sd128:delta4[8:0];inv5<=tab4[10:0];t5<=t4;in5<=in4;
  gap5<=dist4<HALF_GAP-128?4'd0:dist4>=HALF_GAP+128?4'd8:(dist4-(HALF_GAP-128))>>>5;
  inner5<=cover8($signed({3'b0,r2_4,2'b0})-$signed({3'b0,R_IN2,2'b0}),R_IN);
  ring_color6<={shade(8'h25,t5,131),shade(8'h8d,t5,124),shade(8'hb8,t5,81)};
  alpha6<=md[4]==2 && in5?min3(outer6,inner5,gap5):4'd0;
  // Output (edge 7)
  rgb_out<=rgb[5];
  if(enable[5])begin
   if(base5)rgb_out<=24'h407080;
   if(body5)rgb_out<=bar_color5;
   if(cap5)rgb_out<=24'hddfaff;
   if(alpha6!=0)rgb_out<={blend(rgb[5][23:16],ring_color6[23:16],alpha6),
     blend(rgb[5][15:8],ring_color6[15:8],alpha6),blend(rgb[5][7:0],ring_color6[7:0],alpha6)};
  end
 end
end
endmodule
