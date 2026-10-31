`timescale 1ns/1ps
module tb_xga_timing;
reg clk=0;always #5 clk=~clk;
reg rst=1;wire hs,vs,de;wire [7:0] r,g,b;
wire user,valid,last;wire [23:0] data;
color_bar timing(clk,rst,hs,vs,de,r,g,b);
video_rgb_to_axis_640x480 axis(clk,rst,vs,de,24'h123456,user,valid,last,data);
integer px=0,lines=0,frames=0,clocks=0,frame_clock=0;
always @(negedge clk)if(!rst)begin
 clocks=clocks+1;
 if(user && valid)begin
  if(frames!=0 && clocks-frame_clock!=1344*806)$fatal(1,"frame period");
  frames=frames+1;frame_clock=clocks;
 end
 if(valid)begin
  px=px+1;
  if(data!=24'h123456)$fatal(1,"RGB corruption");
  if(last)begin if(px!=1024)$fatal(1,"line length %d",px);px=0;lines=lines+1;end
  else if(px>=1024)$fatal(1,"missing line end");
 end
 if(frames==3)begin
  if(lines!=1536)$fatal(1,"frame line count %d",lines);
  $display("XGA_1344_806_1024_768_AXIS_SOF_EOL_PASS");$finish;
 end
end
initial begin repeat(4)@(negedge clk);rst=0;end
initial begin #40000000;$fatal(1,"timeout");end
endmodule
