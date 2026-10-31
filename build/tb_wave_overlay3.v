`timescale 1ns/1ps
// 3.0 waveform renderer against the unmodified v0.27 audio_ring_overlay:
// identical RGB for every pixel, five clocks later (7 instead of 2).
module tb_wave_overlay3;
reg clk=0;always #5 clk=~clk;
reg rst=1,de=0,en=1;reg [9:0] x=0,y=0;reg [23:0] rgb=0;integer mode=0;
wire [5:0] index;wire [6:0] ref_index;
function [4:0] level(input integer m,input integer i);
 level=m==0?0:m==1?1:m==2?14:m==3?28:m==4?31:(i*7+3)%32;
endfunction
wire [4:0] height=level(mode,index),ref_height=level(mode,ref_index);
wire [23:0] result,ref_rgb;
audio_wave_overlay dut(.clk(clk),.rst(rst),.de(de),.enable(en),.x(x),.y(y),.rgb_in(rgb),
 .bar_height(height),.bar_index(index),.rgb_out(result));
audio_ring_overlay reference(.clk(clk),.rst(rst),.hs(1'b1),.vs(1'b1),.de(de),.enable(en),
 .pixel_x(x),.pixel_y(y[8:0]),.rgb_in(rgb),.bar_height(ref_height),.bar_index(ref_index),
 .hs_out(),.vs_out(),.de_out(),.x_out(),.rgb_out(ref_rgb),.wash_level(2'd2));
reg [23:0] ref_d[0:5],in_d[0:6];reg band_d[0:6];
integer k,age=0,checks=0,white=0,changed=0,outside=0;
reg [79:0] inked=0;reg [31:0] rng=32'h6c0ffee5;
always @(posedge clk)begin
 #1;
 for(k=5;k>0;k=k-1)ref_d[k]=ref_d[k-1];ref_d[0]=ref_rgb;
 for(k=6;k>0;k=k-1)begin in_d[k]=in_d[k-1];band_d[k]=band_d[k-1];end
 in_d[0]=rgb;band_d[0]=de && y>=448 && y<480;
 if(!rst)age=age+1;
 if(age>=8)begin
  // White ink must match the historical renderer; every other pixel is
  // the original photograph now that the blue background has been removed.
  if((ref_d[5]===24'hffffff && result!==24'hffffff) ||
     (ref_d[5]!==24'hffffff && result!==in_d[6]))
   $fatal(1,"unwashed pixel mismatch mode=%0d en=%0d got %h input %h",mode,en,result,in_d[6]);
  checks=checks+1;
  if(result!==in_d[6])begin
   changed=changed+1;
   if(!band_d[6])outside=outside+1;
  end
  if(result===24'hffffff && in_d[6]!==24'hffffff)white=white+1;
 end
end
integer px,py,f;
initial begin
 repeat(4)@(negedge clk);rst=0;
 for(f=0;f<7;f=f+1)begin
  mode=f<6?f:5;en=f!=6;
  for(py=0;py<480;py=py+1)begin
   for(px=0;px<640;px=px+1)begin
    @(negedge clk);de=1;x=px;y=py;
    rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
    rgb=(f==5)?rng[23:0]:{px[7:0],py[7:0],8'h60};
   end
   @(negedge clk);de=0;x=0;y=py;repeat(3)@(negedge clk);
  end
 end
 repeat(12)@(negedge clk);
 if(outside!=0)$fatal(1,"%0d pixels changed outside the y=448..479 band",outside);
 if(white<10000 || changed!=white)$fatal(1,"coverage white=%0d changed=%0d",white,changed);
 $display("WAVE3_OVERLAY_%0d_PIXELS_WHITE_INK_ONLY_NO_BLUE_BACKGROUND_PASS",checks);
 $finish;
end
initial begin #40000000;$fatal(1,"timeout");end
endmodule
