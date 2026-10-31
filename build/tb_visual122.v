`timescale 1ns/1ps
module tb_visual122;
reg clk=0;always #5 clk=~clk;
reg rst=1,vs=1,de=0,valid=0;
reg [37:0] params=38'h1000040080;
reg [23:0] pcm=24'h400000;
wire [23:0] rgb;wire oh,ov,od;
display_enhance fx(.clk(clk),.rst(rst),.hs(1'b1),.vs(vs),.de(de),.display_valid(1'b1),
 .frame_start(1'b0),.rgb_in(24'h123456),.bank(4'd0),.auto_enabled(1'b0),.error_code(8'd0),
 .parameters(params),.alpha(8'd255),.reveal(10'd640),.pcm_valid(valid),.pcm_left(pcm),
 .out_hs(oh),.out_vs(ov),.out_de(od),.rgb_out(rgb));
task tick;begin @(negedge clk);end endtask
task boundary;begin vs=0;repeat(8)tick;vs=1;repeat(8)tick;end endtask
task capture;begin valid=1;repeat(385)tick;valid=0;boundary;end endtask
integer i,j,greens=0,peaks=0,preview,preview_count=0;
reg render=0;
always @(posedge clk)begin
 #2;if(render && od)begin
  $fdisplay(preview,"%0d %0d %0d",rgb[23:16],rgb[15:8],rgb[7:0]);preview_count=preview_count+1;
 end
end
initial begin
 repeat(5)tick;rst=0;params[35]=1;params[32]=1;
 capture;if(fx.wave.display_valid)$fatal(1,"Click-only generated waveform while music off");
 params[31]=1;capture;
 if(!fx.wave.display_valid || fx.wave.display_peak!=64)$fatal(1,"Test PCM capture or peak");
 params[30]=1;capture;
 if(!fx.wave.display_valid || fx.wave.display_peak!=64)$fatal(1,"Mute must preserve test waveform");
 params[32]=0;capture;if(fx.wave.display_peak!=64)$fatal(1,"Click flag affected waveform");
 params[34:33]=3;params[10:8]=7;params[1]=1;
 preview=$fopen("osd_visual.ppm","w");$fdisplay(preview,"P3\n640 480\n255");render=1;
 for(j=0;j<480;j=j+1)begin
  for(i=0;i<640;i=i+1)begin de=1;tick;
   if(od && rgb==24'h20ff90)greens=greens+1;
   if(od && rgb==24'hffb020)peaks=peaks+1;
   if(od && (rgb==24'h20ff90 || rgb==24'hffb020) && (j<352 || j>=416))$fatal(1,"Wave overlaps subtitle or outside region");
  end
  de=0;repeat(8)tick;
 end
 render=0;$fclose(preview);if(preview_count!=307200)$fatal(1,"Preview pixel count");
 if(greens<500 || peaks<50)$fatal(1,"Wave or peak not rendered");
 params[31]=0;repeat(8)tick;
 if(fx.wave.display_valid || fx.wave.capture_count!=0)$fatal(1,"Music stop retained stale capture");
 params[31]=1;params[35]=0;capture;
 if(fx.wave.display_valid)$fatal(1,"Visual off captured waveform");
 params[35]=1;pcm=24'h100000;capture;
 if(!fx.wave.display_valid || fx.wave.display_peak!=16)$fatal(1,"Restart retained old peak");
 $display("TEST_MUSIC_ONLY_VISUAL_FLAGS_MUTE_CLEAR_WAVE_PEAK_REGION_PASS");$finish;
end
initial begin #6000000;$fatal(1,"Visual timeout");end
endmodule
