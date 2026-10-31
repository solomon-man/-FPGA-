`timescale 1ns/1ps
module tb_spectrum;
reg clk=0;always #5 clk=~clk;
reg rst=1,fs=0,de=1,music=1,pv=0;reg [1:0] mode=1;
reg signed [15:0] pcm=0;reg [9:0] x=0,y=0;reg [23:0] photo=24'h305070;
wire [23:0] rgb,final_rgb;
audio_spectrum dut(clk,rst,fs,de,photo,x,y,mode,music,pv,pcm,rgb);
text_layers osd(.rgb(rgb),.de(de),.x(x),.y(y),.page(4'd7),.brightness(9'd0),.contrast(9'd128),.scale(5'd10),
 .transition(2'd0),.subtitle(2'd0),.bank(4'd0),.auto_enabled(1'b0),.error_code(8'd0),.osd_enable(1'b1),.subtitle_enable(1'b0),
 .scroll(10'd0),.out_rgb(final_rgb),.music_track(3'd0),.music_status(3'd0),.visual_mode(mode),.speed(2'd1),.speed_toast(1'b0),.audio_item(2'd3),.mute(1'b0),.music_enable(music),.click_enable(1'b1),.visual_enable(1'b1));
reg [23:0] bg[0:307199];
integer n,k,maxbin,maxval,i,j,f,body_pixels;real v;
reg [47:0] radial_cells;
integer peak_pixels;
task tick;begin @(negedge clk);end endtask
task sample;input integer value;begin
 tick;pcm=value;pv=1;tick;pv=0;repeat(98)tick;
end endtask
task frame;begin tick;fs=1;tick;fs=0;end endtask
task clear_music;begin music=0;repeat(4)tick;music=1;end endtask
task tone;input integer bin_num;begin
 for(n=0;n<1536;n=n+1)sample($rtoi(6000.0*$sin(6.283185307179586*bin_num*n/512.0)));
 maxval=0;maxbin=-1;
 for(k=0;k<16;k=k+1)if(dut.levels[k]>maxval)begin maxval=dut.levels[k];maxbin=k;end
 if(maxbin!=bin_num-1 || maxval<40)$fatal(1,"DFT wrong peak: tone bin=%d peak=%d amplitude=%d",bin_num,maxbin,maxval);
 if(dut.levels[(bin_num+5)%16]>5)$fatal(1,"Spectrum leakage excessive");
end endtask
initial begin
 $readmemh("spectrum_background.hex",bg);
 repeat(5)tick;rst=0;tone(4);
 if(dut.shown[3]!=0)$fatal(1,"Levels changed without frame boundary");
 frame;if(dut.shown[3]<40)$fatal(1,"Frame snapshot missing");
 clear_music;tone(10);frame;
 clear_music;
 for(n=0;n<1536;n=n+1)begin
 v=6000.0*$sin(6.283185307179586*3*n/512.0)+4000.0*$sin(6.283185307179586*5*n/512.0)+
   3000.0*$sin(6.283185307179586*8*n/512.0)+2000.0*$sin(6.283185307179586*12*n/512.0);
 sample($rtoi(v));
 end
 frame;
 for(j=1;j<=2;j=j+1)begin
 mode=j;
 if(j==1)f=$fopen("../docs/spectrum_bars.ppm","w");else f=$fopen("../docs/spectrum_radial.ppm","w");
 $fwrite(f,"P3\n640 480\n255\n");
 for(i=0;i<307200;i=i+1)begin x=i%640;y=i/640;photo=bg[i];#1;
 $fwrite(f,"%0d %0d %0d\n",final_rgb[23:16],final_rgb[15:8],final_rgb[7:0]);end
 $fclose(f);
 end
 // Verify compact bounds at full level, independently of the tone amplitudes.
 for(k=0;k<16;k=k+1)begin dut.shown[k]=96;dut.peaks[k]=96;end
 mode=1;y=432;body_pixels=0;
 for(i=0;i<640;i=i+1)begin
  x=i;#1;
  if(dut.body)begin
   body_pixels=body_pixels+1;
   if(i<192 || i>=448 || (i-192)%8<2 || (i-192)%8>=5)$fatal(1,"Bar width/location");
  end
 end
 if(body_pixels!=96)$fatal(1,"Expected thirty-two 3-pixel bars");
 mode=2;
 for(i=0;i<4;i=i+1)begin
  case(i)
   0:begin x=625;y=392;end
   1:begin x=479;y=392;end
   2:begin x=552;y=465;end
   3:begin x=552;y=319;end
  endcase
  #1;if(rgb!==photo)$fatal(1,"Outer circle must be absent");
 end
 x=604;y=444;#1;if(rgb!==photo)$fatal(1,"Outer diagonal circle must be absent");
 x=576;y=392;#1;if(rgb!==24'h75b9c8)$fatal(1,"Inner ring X radius");
 x=552;y=416;#1;if(rgb!==24'h75b9c8)$fatal(1,"Inner ring Y radius");
 x=605;y=445;#1;if(rgb!==photo)$fatal(1,"Radial must not become a square");
 x=552;y=392;#1;if(rgb!==photo)$fatal(1,"Ring must leave center clear");
 x=320;y=280;#1;if(rgb!==photo)$fatal(1,"Old radial position still active");
 $display("COMPACT_SPECTRUM_THIN_BARS_ROUND_LOWER_RIGHT_BOUNDS_PASS");
 radial_cells=0;peak_pixels=0;
 for(j=318;j<=466;j=j+1)for(i=478;i<=626;i=i+1)begin
  x=i;y=j;#1;
  if(dut.body)radial_cells[dut.sector]=1'b1;
  if(dut.cap)begin
   peak_pixels=peak_pixels+1;
   if(rgb!==24'hddfaff)$fatal(1,"Peak highlight missing");
  end
  if((i-552)*(i-552)+(j-392)*(j-392)>=5476 && rgb!==photo)
   $fatal(1,"Radial pixels outside circular boundary");
 end
 if(radial_cells!==48'hffffffffffff || peak_pixels<48)
  $fatal(1,"Fine radial cells/peak coverage missing");
 $display("RADIAL_48_SEGMENTS_NO_OUTER_RING_32_BARS_SAME_WIDTH_PASS");
 mode=0;x=320;y=380;#1;if(rgb!==photo)$fatal(1,"Disabled visual changes photo");
 mode=2;music=0;#1;if(rgb!==photo)$fatal(1,"Music-off visual changes photo");
 repeat(4)tick;music=1;
 for(n=0;n<512;n=n+1)sample(0);frame;
 for(k=0;k<16;k=k+1)if(dut.shown[k]!=0)$fatal(1,"Silence not zero");
 $display("REAL_DFT_FREQUENCY_SELECTIVITY_SILENCE_FRAME_ATOMIC_BARS_RADIAL_PASS");$finish;
end
initial begin #10000000;$fatal(1,"Spectrum timeout");end
endmodule
