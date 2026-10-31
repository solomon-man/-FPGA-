`timescale 1ns/1ps
module tb_osd_render;
reg [23:0] input_rgb;reg [9:0] x,y;
reg [3:0] image_num=1;
reg [3:0] page=4;reg [1:0] audio_item=1,speed=1;reg toast=0;reg [2:0] track=0,sd_status=0;wire [23:0] output_rgb;
reg [23:0] photo[0:307199];
integer file_handle,px,py,mode;
text_layers #(.ENABLE_TEMPERATURE(1)) layers(.rgb(input_rgb),.de(1'b1),.x(x),.y(y),.page(page),.temperature(7'sd24),
 .brightness(-9'sd32),.contrast(9'd160),.scale(5'd15),.transition(2'd1),
 .subtitle(2'd2),.bank(image_num),.auto_enabled(1'b1),.error_code(8'd0),
 .osd_enable(1'b1),.subtitle_enable(1'b0),.music_track(track),.music_status(sd_status),.visual_mode(2'd2),.speed(speed),.speed_toast(toast),.audio_item(audio_item),.visual_enable(1'b1),.mute(1'b0),.music_enable(1'b1),.click_enable(1'b1),.scroll(10'd0),.out_rgb(output_rgb));
initial begin
 for(mode=0;mode<10;mode=mode+1)begin
  image_num=mode==1?9:1;
  page=mode==0?4:mode==1?6:mode==2?7:0;toast=mode>=3 && mode<6;speed=mode>=3?mode-3:1;
  case(mode)
  0:file_handle=$fopen("osd_brightness.ppm","w");
  1:file_handle=$fopen("osd_overview.ppm","w");
  2:file_handle=$fopen("osd_audio.ppm","w");
  3:file_handle=$fopen("osd_fast.ppm","w");
  4:file_handle=$fopen("osd_medium.ppm","w");
  6:file_handle=$fopen("osd_sd_music.ppm","w");
  7:file_handle=$fopen("osd_sd_load.ppm","w");
  8:file_handle=$fopen("osd_sd_error.ppm","w");
  9:file_handle=$fopen("osd_temperature.ppm","w");
  5:file_handle=$fopen("osd_slow.ppm","w");
 endcase
  if(mode>=6)begin page=7;track=2;sd_status=mode==6?2:mode==7?1:4;end
  if(mode==9)begin page=8;toast=0;end
  $fdisplay(file_handle,"P3\n640 480\n255");
  for(py=0;py<480;py=py+1)for(px=0;px<640;px=px+1)begin
   x=px;y=py;input_rgb=24'h183048;#1;
   if(py>=224 && output_rgb!=input_rgb)$fatal(1,"Overlay leaked into image");
   $fdisplay(file_handle,"%0d %0d %0d",output_rgb[23:16],output_rgb[15:8],output_rgb[7:0]);
  end
  $fclose(file_handle);
 end
 $display("RTL_OSD_RENDER_PANELS_SPEED_MUSIC_NO_SUBTITLE_PASS");$finish;
end
endmodule
