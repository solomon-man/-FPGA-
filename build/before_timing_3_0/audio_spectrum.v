// 16-bin, 512-sample real DFT @ 48 kHz; bins 93.75 .. 1500 Hz.
// Triangular window, shared arithmetic, attack/decay, frame-atomic display.
// Input is selected test/SD music PCM before the mixer; click sound is excluded.
module audio_spectrum #(parameter PIPELINED_RENDER=0)(input clk,rst,frame_start,de,
 input [23:0] rgb_in,input [9:0] x,y,input [1:0] mode,input music_enable,
 input pcm_valid,input signed [15:0] pcm_left,output reg [23:0] rgb_out);
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
reg signed [31:0] acc_r[0:15],acc_i[0:15],sum_r,sum_i;
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
integer i;
always @(posedge clk or posedge rst)begin
 if(rst)begin
  state<=0;sample_n<=0;angle<=0;bin<=0;window_product<=0;windowed<=0;
  prod_r<=0;prod_i<=0;sum_r<=0;sum_i<=0;
  abs_r_q<=0;abs_i_q<=0;target_q<=0;bin_abs<=0;bin_target<=0;update_abs<=0;update_target<=0;
  for(i=0;i<16;i=i+1)begin levels[i]<=0;shown[i]<=0;peaks[i]<=0;end
 end else begin
  abs_r_q<=abs_r;abs_i_q<=abs_i;bin_abs<=bin;update_abs<=music_enable && state==4 && sample_n==511;
  target_q<=target_level;bin_target<=bin_abs;update_target<=music_enable && update_abs;
  if(!music_enable)begin
   state<=0;sample_n<=0;
   for(i=0;i<16;i=i+1)begin levels[i]<=0;shown[i]<=0;peaks[i]<=0;end
  end else begin
   if(frame_start)for(i=0;i<16;i=i+1)begin
    shown[i]<=levels[i];
    peaks[i]<=levels[i]>=peaks[i]?levels[i]:peaks[i]!=0?peaks[i]-1'b1:0;
   end
   if(update_target)levels[bin_target]<=target_q>=levels[bin_target]?target_q:
     levels[bin_target]>2 && target_q<levels[bin_target]-2?levels[bin_target]-2:target_q;
   case(state)
    0:if(pcm_valid)begin
     window_product<= $signed(pcm_left[15:4])*$signed({1'b0,window_weight});
     bin<=0;angle<=sample_n;state<=1;
    end
    1:begin windowed<=window_product>>>8;state<=2;end
    2:begin prod_r<=windowed*sine(angle+9'd128);prod_i<=windowed*sine(angle);state<=3;end
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
// Compact bars: 32 bodies at 8-pixel pitch, sharing 16 analyzed bands.
// Radial: equal-axis circular annulus in the lower-right corner.
reg [9:0] ax,ay;
reg [6:0] major,minor;
reg [9:0] angular_remainder;
reg [2:0] octant_angle;
reg [3:0] quadrant_angle;
reg [5:0] sector;
reg [3:0] band;
reg [6:0] height,peak;
reg [6:0] outer;
reg [14:0] radius2;
reg [13:0] outer2;
reg [6:0] peak_radius;
reg [13:0] peak_radius2;
reg panel,body,cap,base_line,gap;
reg [23:0] color;
reg [7:0] bx;
generate if (PIPELINED_RENDER==0) begin: legacy_render
always @*begin
 ax=x>=552?x-552:552-x;ay=y>=392?y-392:392-y;
 // Radius arithmetic is used only inside the separately checked 74px bounds.
 major=ax>=ay?ax[6:0]:ay[6:0];minor=ax>=ay?ay[6:0]:ax[6:0];
 // Six cells per octant, 48 around the circle; bounded compare/subtract stages.
 angular_remainder={1'b0,minor,2'b0}+{2'd0,minor,1'b0};octant_angle=0;
 if(angular_remainder>={1'b0,major,2'd0})begin
  angular_remainder=angular_remainder-{1'b0,major,2'd0};octant_angle[2]=1;
 end
 if(angular_remainder>={2'd0,major,1'b0})begin
  angular_remainder=angular_remainder-{2'd0,major,1'b0};octant_angle[1]=1;
 end
 if(angular_remainder>={3'd0,major})begin
  angular_remainder=angular_remainder-{3'd0,major};octant_angle[0]=1;
 end
 quadrant_angle=ax>=ay?{1'b0,octant_angle}:4'd11-octant_angle;
 sector=x>=552?(y>=392?{2'b0,quadrant_angle}:6'd47-quadrant_angle):
                 (y>=392?6'd23-quadrant_angle:6'd24+quadrant_angle);
 bx=x-192;band=mode==2?sector[3:0]:bx[7:4];
 height=shown[band]>>1;peak=peaks[band]>>1;outer=8'd24+height;
 radius2=ax[6:0]*ax[6:0]+ay[6:0]*ay[6:0];outer2=outer*outer;
 peak_radius=7'd24+peak;peak_radius2=peak_radius*peak_radius;
 panel=0;body=0;cap=0;base_line=0;
 gap=minor==0 || major==minor || angular_remainder<7;
 color={8'd40,8'd140+{1'b0,height},8'hff};
 if(mode==1 && x>=192 && x<448 && y>=400 && y<465)begin
  panel=1;
  if(bx[2:0]>=2 && bx[2:0]<5)begin
   body=height!=0 && y<456 && y>=456-height;
   cap=peak!=0 && y>=454-peak && y<456-peak;
   base_line=y==456;
  end
 end
 if(mode==2 && ax<74 && ay<74 && radius2>=576 && radius2<5476)begin
  body=height!=0 && radius2<outer2 && !gap;
  cap=peak>3 && !gap && radius2<peak_radius2 &&
      radius2+{6'd0,peak_radius,1'b0}>=peak_radius2;
  base_line=radius2<625;
  // Concentric highlights and an open center retain a true circular outline.
  if(radius2<1296)color=24'h258db8;
  else if(radius2<2500)color=24'h29c6e0;
  else color=24'h86e9f4;
 end
 rgb_out=rgb_in;
 if(de && music_enable && mode!=0)begin
  if(panel)begin
   if(mode==2)rgb_out={rgb_in[23:16]-{3'b0,rgb_in[23:19]},
     rgb_in[15:8]-{3'b0,rgb_in[15:11]},rgb_in[7:0]-{3'b0,rgb_in[7:3]}};
   else rgb_out={1'b0,rgb_in[23:17],1'b0,rgb_in[15:9],1'b0,rgb_in[7:1]};
  end
  if(base_line)rgb_out=mode==2?24'h75b9c8:24'h407080;
  if(body)rgb_out=color;
  if(cap)rgb_out=24'hddfaff;
 end
end
end else begin: pipelined_render
wire [111:0] heights, peak_values;
for(genvar b=0;b<16;b=b+1) begin: bundle
 assign heights[b*7+:7]=shown[b];
 assign peak_values[b*7+:7]=peaks[b];
end
wire [23:0] result;
spectrum_renderer_pipeline renderer(clk,rst,de,rgb_in,x,y,mode,music_enable,heights,peak_values,result);
always @* rgb_out=result;
end endgenerate
endmodule

// Seven pixel clocks. Keep the exact squared-distance circle and RGB888
// arithmetic; register angle, lookup, squares and comparison independently.
module spectrum_renderer_pipeline(input clk,rst,de,input [23:0] rgb_in,
 input [9:0] x,y,input [1:0] mode,input music_enable,
 input [111:0] heights,peak_values,output reg [23:0] rgb_out);
reg [23:0] rgb[0:5];reg [9:0] xx[0:5],yy[0:5];
reg [1:0] md[0:5];reg [5:0] enable;
reg [9:0] ax0,ay0;
reg [6:0] major1,minor1;reg swap1,right1,bottom1,bounds1;
reg [14:0] radius1,radius2,radius3,radius4;
reg bounds2,bounds3,bounds4,gap2,gap3,gap4;
reg [3:0] band2;reg [6:0] height3,peak3,outer3,peak_radius3;
reg [6:0] height4,peak4,peak_radius4;
reg [13:0] outer_square4,peak_square4;
reg body5,cap5,base5,panel5;reg [23:0] color5;
reg [9:0] remainder;reg [2:0] octant;reg [3:0] quadrant;
reg [5:0] sector;reg [7:0] bx;
integer i;
always @*begin
 remainder={1'b0,minor1,2'b0}+{2'b0,minor1,1'b0};octant=0;
 if(remainder>={1'b0,major1,2'b0})begin remainder=remainder-{1'b0,major1,2'b0};octant[2]=1;end
 if(remainder>={2'b0,major1,1'b0})begin remainder=remainder-{2'b0,major1,1'b0};octant[1]=1;end
 if(remainder>={3'b0,major1})begin remainder=remainder-{3'b0,major1};octant[0]=1;end
 quadrant=swap1?4'd11-octant:{1'b0,octant};
 sector=right1?(bottom1?{2'b0,quadrant}:6'd47-quadrant):
               (bottom1?6'd23-quadrant:6'd24+quadrant);
 bx=xx[1]-192;
end
always @(posedge clk or posedge rst)begin
 if(rst)begin
  for(i=0;i<6;i=i+1)begin rgb[i]<=0;xx[i]<=0;yy[i]<=0;md[i]<=0;end
  enable<=0;rgb_out<=0;ax0<=0;ay0<=0;major1<=0;minor1<=0;
  swap1<=0;right1<=0;bottom1<=0;bounds1<=0;bounds2<=0;bounds3<=0;bounds4<=0;
  radius1<=0;radius2<=0;radius3<=0;radius4<=0;band2<=0;gap2<=0;gap3<=0;gap4<=0;
  height3<=0;peak3<=0;outer3<=0;peak_radius3<=0;height4<=0;peak4<=0;peak_radius4<=0;
  outer_square4<=0;peak_square4<=0;body5<=0;cap5<=0;base5<=0;panel5<=0;color5<=0;
 end else begin
  rgb[0]<=rgb_in;xx[0]<=x;yy[0]<=y;md[0]<=mode;
  enable<={enable[4:0],de && music_enable && mode!=0};
  for(i=1;i<6;i=i+1)begin rgb[i]<=rgb[i-1];xx[i]<=xx[i-1];yy[i]<=yy[i-1];md[i]<=md[i-1];end
  ax0<=x>=552?x-552:552-x;ay0<=y>=392?y-392:392-y;
  major1<=ax0>=ay0?ax0[6:0]:ay0[6:0];minor1<=ax0>=ay0?ay0[6:0]:ax0[6:0];
  swap1<=ax0<ay0;right1<=xx[0]>=552;bottom1<=yy[0]>=392;bounds1<=ax0<74 && ay0<74;
  radius1<=ax0[6:0]*ax0[6:0]+ay0[6:0]*ay0[6:0];
  band2<=md[1]==2?sector[3:0]:bx[7:4];
  gap2<=minor1==0 || major1==minor1 || remainder<7;bounds2<=bounds1;radius2<=radius1;
  height3<=heights[band2*7+:7]>>1;peak3<=peak_values[band2*7+:7]>>1;
  outer3<=7'd24+(heights[band2*7+:7]>>1);peak_radius3<=7'd24+(peak_values[band2*7+:7]>>1);
  gap3<=gap2;bounds3<=bounds2;radius3<=radius2;
  outer_square4<=outer3*outer3;peak_square4<=peak_radius3*peak_radius3;
  height4<=height3;peak4<=peak3;peak_radius4<=peak_radius3;
  gap4<=gap3;bounds4<=bounds3;radius4<=radius3;
  body5<=0;cap5<=0;base5<=0;panel5<=0;color5<={8'd40,8'd140+{1'b0,height4},8'hff};
  if(md[4]==1 && xx[4]>=192 && xx[4]<448 && yy[4]>=400 && yy[4]<465)begin
   panel5<=1;
   if(xx[4][2:0]>=2 && xx[4][2:0]<5)begin
    body5<=height4!=0 && yy[4]<456 && yy[4]>=456-height4;
    cap5<=peak4!=0 && yy[4]>=454-peak4 && yy[4]<456-peak4;
    base5<=yy[4]==456;
   end
  end
  if(md[4]==2 && bounds4 && radius4>=576 && radius4<5476)begin
   body5<=height4!=0 && radius4<outer_square4 && !gap4;
   cap5<=peak4>3 && !gap4 && radius4<peak_square4 && radius4+{6'd0,peak_radius4,1'b0}>=peak_square4;
   base5<=radius4<625;
   if(radius4<1296)color5<=24'h258db8;
   else if(radius4<2500)color5<=24'h29c6e0;
   else color5<=24'h86e9f4;
  end
  rgb_out<=rgb[5];
  if(enable[5])begin
   if(panel5)rgb_out<={1'b0,rgb[5][23:17],1'b0,rgb[5][15:9],1'b0,rgb[5][7:1]};
   if(base5)rgb_out<=md[5]==2?24'h75b9c8:24'h407080;
   if(body5)rgb_out<=color5;
   if(cap5)rgb_out<=24'hddfaff;
  end
 end
end
endmodule
