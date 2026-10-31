// Debounced release actions. Chords consume BOTH releases, including staggered ones.
module display_controls4 #(parameter integer DEBOUNCE=2_000_000,HOLD=100_000_000,
 parameter integer TOAST_CYCLES=150_000_000,HAS_SD_AUDIO=0,PER_PHOTO=0)(
 input clk,rst,key1,key2,key3,key4,input [3:0] dip,
 output reg next_event,auto_event,prev_event,output reg [3:0] page,
 output reg signed [8:0] brightness,output reg [8:0] contrast,
 output reg [4:0] scale,output reg [1:0] transition,subtitle,output reg osd_enable,subtitle_enable,
 output reg [1:0] audio_item,output reg mute,music_enable,click_enable,visual_enable,
 output reg [1:0] visual_mode,speed,output wire speed_toast,output reg reset_all_event,
 input [2:0] track_count,output reg [2:0] music_track,
 output reg signed [6:0] temperature,
 input [3:0] photo_index,output reg [3:0] parameter_photo);
// Store only adjustable bits: temperature / 8, scale, contrast / 16.
reg [13:0] photo_settings[0:9];
reg [9:0] photo_settings_valid;
reg [13:0] lookup_settings;
reg [3:0] lookup_photo;
localparam [13:0] PHOTO_DEFAULT={4'd0,5'd10,5'd8};
wire [2:0] tracks=HAS_SD_AUDIO?track_count:3'd0;
reg [3:0] meta,sync,stable,candidate,armed,blocked;
reg [3:0] dm,ds,dc,dstable;
// Counters saturate at DEBOUNCE; avoid unused upper bits and carry chains.
localparam integer DEBOUNCE_BITS=DEBOUNCE<2?1:$clog2(DEBOUNCE+1);
reg [DEBOUNCE_BITS-1:0] debounce_count[0:3],dip_count;
reg chord,chord34;reg [3:0] selected;integer i;
reg [27:0] toast_count;
assign speed_toast=toast_count!=0;
wire context_ok=(page==selected && ds==dstable && (!PER_PHOTO || photo_index==parameter_photo));
wire music_page=(page==7 && audio_item==1);
// Keep the data array free of asynchronous resets so synthesis can use RAM.
// The validity bits supply neutral values after reset without clearing RAM.
always @(posedge clk)begin
 if(PER_PHOTO && !rst)photo_settings[parameter_photo]<={temperature[6:3],scale,contrast[8:4]};
end
always @* begin
 case(dstable)
  0:selected=0;1:selected=4;2:selected=5;4:selected=3;8:selected=2;
  3:selected=1;5:selected=7;9:selected=8;default:selected=6;
 endcase
end
always @(posedge clk or posedge rst)begin
 if(rst)begin
  meta<=15;sync<=15;stable<=15;candidate<=15;armed<=0;blocked<=0;chord<=0;chord34<=0;
  dm<=0;ds<=0;dc<=0;dstable<=0;dip_count<=0;
  for(i=0;i<4;i=i+1)debounce_count[i]<=0;
  next_event<=0;prev_event<=0;auto_event<=0;page<=0;reset_all_event<=0;
  brightness<=0;contrast<=128;scale<=10;transition<=0;subtitle<=0;temperature<=0;
  osd_enable<=0;subtitle_enable<=0;audio_item<=0;mute<=0;music_enable<=0;click_enable<=0;visual_enable<=0;
  visual_mode<=0;speed<=1;toast_count<=0;music_track<=0;
  parameter_photo<=0;
  lookup_photo<=0;lookup_settings<=PHOTO_DEFAULT;
  photo_settings_valid<=0;
 end else begin
  meta<={key4,key3,key2,key1};sync<=meta;dm<=dip;ds<=dm;
  next_event<=0;prev_event<=0;auto_event<=0;reset_all_event<=0;
  visual_enable<=visual_mode!=0;
  if(toast_count!=0)toast_count<=toast_count-1'b1;
  if(ds!=dc)begin dc<=ds;dip_count<=0;end
  else if(dip_count<DEBOUNCE)dip_count<=dip_count+1'b1;
  else dstable<=dc;
  page<=selected;osd_enable<=selected!=0;
  if(page!=7 && selected==7)audio_item<=0;
  for(i=0;i<4;i=i+1)begin
   if(sync[i]!=candidate[i])begin candidate[i]<=sync[i];debounce_count[i]<=0;end
   else if(debounce_count[i]<DEBOUNCE)debounce_count[i]<=debounce_count[i]+1'b1;
   else stable[i]<=candidate[i];
   if(!stable[i])armed[i]<=1;
   else begin
    if(armed[i] && !blocked[i] && context_ok)begin
     case(i)
      // Music navigation is local to MUSIC; test is track zero.
      0:if(!chord && stable[1])begin
       if(music_page)music_track<=music_track==0?tracks:music_track-1'b1;
       else prev_event<=1;
      end
      1:if(!chord && stable[0])begin
       if(music_page)music_track<=music_track>=tracks?0:music_track+1'b1;
       else next_event<=1;
      end
      2,3:if(!chord34)case(page)
       1:speed<=i==3?((speed==2)?0:speed+1'b1):((speed==0)?2:speed-1'b1);
       2:transition<=i==3?((transition==2)?0:transition+1'b1):((transition==0)?2:transition-1'b1);
       3:if(i==3 && scale<20)scale<=scale+1'b1;
         else if(i==2 && scale>3)scale<=scale-1'b1;
       7:if(i==2)audio_item<=audio_item+1'b1;
         else case(audio_item)
          0:mute<=~mute;1:music_enable<=~music_enable;2:click_enable<=~click_enable;
          3:visual_mode<=visual_mode+1'b1; // OFF,BARS,RADIAL,WAVE
         endcase
       4:if(i==3 && brightness<96)brightness<=brightness+16;
         else if(i==2 && brightness>-96)brightness<=brightness-16;
       5:if(i==3 && contrast<256)contrast<=contrast+16;
         else if(i==2 && contrast>32)contrast<=contrast-16;
       8:if(i==3 && temperature<48)temperature<=temperature+7'sd8;
         else if(i==2 && temperature>-48)temperature<=temperature-7'sd8;
       default:begin end
      endcase
     endcase
    end
    armed[i]<=0;blocked[i]<=0;
   end
  end
  if(!stable[0] && !stable[1] && !chord)begin
   chord<=1;
   if(context_ok && blocked[1:0]==0 && !music_page)auto_event<=1;
  end
  if(stable[0] && stable[1])chord<=0;
  if(!stable[2] && !stable[3] && !chord34)begin
   chord34<=1;
   if(context_ok && blocked[3:2]==0)case(page)
    0:begin speed<=speed==2?0:speed+1'b1;toast_count<=TOAST_CYCLES;end
    1:speed<=1;
    2:transition<=0;
    3:scale<=10;
    4:brightness<=0;
    5:contrast<=128;
    8:temperature<=0;
    7:case(audio_item)
     0:mute<=0;1:begin music_enable<=0;music_track<=0;end 2:click_enable<=0;3:visual_mode<=0;
    endcase
    6:begin
     brightness<=0;contrast<=128;scale<=10;transition<=0;temperature<=0;
     mute<=0;music_enable<=0;click_enable<=0;visual_mode<=0;audio_item<=0;music_track<=0;
     speed<=1;toast_count<=0;reset_all_event<=1;
    end
   endcase
  end
  if(stable[2] && stable[3])chord34<=0;
  if(!context_ok)begin blocked<=blocked|~stable;armed<=0;end
  // A held navigation key cannot leak out of the MUSIC submenu.
  if(page==7 && armed[2] && stable[2] && !chord34)begin
   blocked[1:0]<=blocked[1:0]|~stable[1:0];armed[1:0]<=0;
  end
  if(PER_PHOTO)begin
   // Split the ten-entry read mux from the controls/update mux at 100 MHz.
   // Only acknowledge the photo after its tagged lookup has arrived.
   lookup_photo<=photo_index;
   if(photo_index<10)lookup_settings<=photo_settings_valid[photo_index]?photo_settings[photo_index]:PHOTO_DEFAULT;
   photo_settings_valid[parameter_photo]<=1;
   if(photo_index<10 && photo_index!=parameter_photo && lookup_photo==photo_index)begin
    parameter_photo<=photo_index;
    {temperature,scale,contrast}<={lookup_settings[13:10],3'd0,lookup_settings[9:5],lookup_settings[4:0],4'd0};
   end
   // Overview reset clears every photo, including those evicted from SDRAM.
   if(reset_all_event)begin
    photo_settings_valid<=0;
    temperature<=0;scale<=10;contrast<=128;
   end
  end
 end
end
endmodule
