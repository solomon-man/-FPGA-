`timescale 1ns/1ps
module tb_photo_settings;
reg clk=0,pclk=0;always #5 clk=~clk;always #20 pclk=~pclk;
reg rst=1,k3=1,k4=1;reg [3:0] dip=0,photo=0;wire [3:0] saved_photo;
wire [8:0] contrast;wire [4:0] scale;wire signed [6:0] temp;wire reset_all;
display_controls4 #(.DEBOUNCE(2),.PER_PHOTO(1)) ctrl(.clk(clk),.rst(rst),
 .key1(1'b1),.key2(1'b1),.key3(k3),.key4(k4),.dip(dip),.track_count(3'd0),
 .contrast(contrast),.scale(scale),.temperature(temp),.reset_all_event(reset_all),
 .photo_index(photo),.parameter_photo(saved_photo));
reg frame=0;reg [1:0] wanted_bank=0,mode=0;reg valid=0,permit=1;
wire [1:0] active_bank;wire [24:0] settings;wire [7:0] alpha;
reg [9:0] x=128;wire [23:0] osd_rgb;
text_layers #(.ENABLE_TEMPERATURE(1)) osd(.rgb(24'h808080),.de(1'b1),.x(x),.y(10'd108),
 .page(4'd6),.brightness(9'd0),.contrast(contrast),.scale(scale),.temperature(temp),
 .transition(2'd0),.subtitle(2'd0),.bank(photo),.auto_enabled(1'b0),.error_code(8'd0),
 .osd_enable(1'b1),.subtitle_enable(1'b0),.scroll(10'd0),.out_rgb(osd_rgb),
 .music_track(3'd0),.music_status(3'd0),.visual_mode(2'd0),.speed(2'd1),.speed_toast(1'b0),
 .audio_item(2'd0),.mute(1'b0),.music_enable(1'b0),.click_enable(1'b0),.visual_enable(1'b0));
status_seven_segment digits(.clk(clk),.rst(rst),.page(4'd6),.brightness(9'd0),.contrast(contrast),
 .scale(scale),.temperature(temp),.transition(2'd0),.subtitle(2'd0),.bank(photo),
 .subtitle_enable(1'b0),.auto_enabled(1'b0),.fat_status(2'd2),.error_code(8'd0),.state_code(4'd0),
 .music_track(3'd0),.visual_mode(2'd0),.speed(2'd1),.audio_item(2'd0),.mute(1'b0),
 .music_enable(1'b0),.click_enable(1'b0),.visual_enable(1'b0),.seg_sel(),.seg_data());
frame_commit #(.ENABLE_EFFECTS(1),.PER_PHOTO(1)) fc(.clk(pclk),.rst(rst),.frame_req(frame),
 .source_clk(clk),.source_rst(rst),.requested_bank(wanted_bank),.requested_valid(valid),
 .active_bank(active_bank),.active_valid(),.memory_req(),.frame_start(),.transition_mode(mode),.alpha(alpha),.reveal(),
 .source_ready(permit && saved_photo==photo),.requested_settings({saved_photo,temp,scale,contrast}),.active_settings(settings));
task tick;begin @(negedge clk);end endtask
task press;input integer up;begin k3=up;k4=!up;repeat(12)tick;k3=1;k4=1;repeat(12)tick;end endtask
task choose;input [3:0] d;begin dip=d;repeat(20)tick;end endtask
task switch_photo;input [3:0] p;begin photo=p;repeat(25)tick;end endtask
task chord;begin k3=0;k4=0;repeat(20)tick;k3=1;k4=1;repeat(20)tick;end endtask
task boundary;begin @(negedge pclk);frame=1;@(negedge pclk);frame=0;repeat(3)@(negedge pclk);end endtask
integer i,j;reg [24:0] old_settings;
initial begin
 repeat(5)tick;rst=0;repeat(20)tick;
 for(i=0;i<10;i=i+1)begin
  switch_photo(i);
  if(contrast!=128 || scale!=10 || temp!=0)$fatal(1,"New photo not neutral");
  choose(2);repeat(i%7)press(1);
  choose(4);repeat(i)press(1);
  choose(9);repeat(i%7)press(0);
 end
 for(i=9;i>=0;i=i-1)begin
  switch_photo(i);
  if(contrast!=128+16*(i%7) || scale!=10+i || temp!=-8*(i%7))$fatal(1,"Per-photo restore failed %d",i);
 end
 // Cancel a lookup before its tag can be acknowledged; never restore it to
 // the following photo or overwrite either saved record.
 photo=9;tick;photo=8;repeat(25)tick;
 if(saved_photo!=8 || contrast!=144 || scale!=18 || temp!=-8)$fatal(1,"Canceled lookup leaked into next photo");
 switch_photo(9);
 if(contrast!=160 || scale!=19 || temp!=-16)$fatal(1,"Canceled lookup corrupted saved photo");
 switch_photo(9);choose(2);chord;
 x=16+7*16;#1;if(osd.c!="1")$fatal(1,"OSD photo ten tens");
 x=16+8*16;#1;if(osd.c!="0")$fatal(1,"OSD photo ten units");
 if(digits.digits[5]!=0 || digits.digits[6]!=1)$fatal(1,"Photo ten digit display");
 if(contrast!=128 || scale!=19 || temp!=-16)$fatal(1,"Current reset affected other fields");
 switch_photo(8);if(contrast!=144 || scale!=18 || temp!=-8)$fatal(1,"Current reset affected other photo");
 // Capture photo 9; then fade to photo 10 with all fields committed together.
 valid=1;repeat(40)tick;boundary;old_settings=settings;
 if(settings!=={4'd8,-7'sd8,5'd18,9'd144})$fatal(1,"Initial bundled parameters");
 mode=1;wanted_bank=1;switch_photo(9);repeat(40)tick;
 for(j=0;j<16;j=j+1)begin boundary;if(settings!==old_settings || active_bank!=0)$fatal(1,"New settings applied before fade commit");end
 boundary;
 if(settings!=={4'd9,-7'sd16,5'd19,9'd128} || active_bank!=1 || alpha!=0)$fatal(1,"Frame commit lost image/parameter atomicity");
 repeat(16)boundary;
 choose(15);chord;
 for(i=0;i<10;i=i+1)begin switch_photo(i);if(contrast!=128 || scale!=10 || temp!=0)$fatal(1,"Overview reset did not reset every photo");end
 choose(9);press(1);rst=1;repeat(5)tick;rst=0;repeat(20)tick;
 for(i=0;i<10;i=i+1)begin switch_photo(i);if(contrast!=128 || scale!=10 || temp!=0)$fatal(1,"Hardware reset did not clear table");end
 $display("TEN_PHOTO_INDEPENDENT_CONTRAST_ZOOM_TEMP_CURRENT_ALL_RESET_FRAME_ATOMIC_FADE_PASS");$finish;
end
initial begin #2000000;$fatal(1,"Photo settings timeout");end
endmodule
