`timescale 1ns/1ps
// Spectrum renderer, seven clocks.
// A: OFF/BARS (and RADIAL away from the ring) equal the shipped 3.0 renderer
//    pixel for pixel over 640x480, three height sets.
// B: RADIAL over a full XGA frame, random photo: untouched outside the ring
//    box; inside it the RTL is dumped to radial_rtl.hex for check_radial.py.
// C: before/after preview dumps on a smooth background (radial_preview.hex).
module tb_render_pipeline;
reg clk=0;always #5 clk=~clk;
reg rst=1,de=0,music=0;reg [9:0] x=0,y=0,xga_x=0,xga_y=0;reg [1:0] mode=0;
reg [23:0] rgb=0;wire [23:0] reference_rgb,result;
reg [33:0] sent[0:6];  // {in ring box, rgb} seven clocks ago
integer i,n,m,xx,yy,f,boxed=0;
reg [31:0] rng=32'h9137cdfe;
reg check_a=0,check_b=0,dump=0;
audio_spectrum_v30 #(.PIPELINED_RENDER(1)) ref_dut(clk,rst,1'b0,de,rgb,x,y,mode,music,1'b0,16'd0,reference_rgb);
audio_spectrum dut(clk,rst,1'b0,de,rgb,x,y,mode,music,1'b0,16'd0,result,xga_x,xga_y);
wire in_box=(xga_x>=884-95 && xga_x<=884+95 && xga_y>=628-95 && xga_y<=628+95);
always @(posedge clk)if(!rst)begin
 for(i=6;i>0;i=i-1)sent[i]=sent[i-1];
 sent[0]={in_box,rgb};
 #1;
 if(check_a && result!==reference_rgb)
  $fatal(1,"3.0 mismatch x=%0d y=%0d mode=%0d expected %h actual %h",x,y,mode,reference_rgb,result);
 if(check_b)begin
  if(!sent[6][24] && result!==sent[6][23:0])$fatal(1,"radial changed a pixel outside the ring box");
  if(sent[6][24] && dump)begin $fwrite(f,"%h %h\n",sent[6][23:0],result);boxed=boxed+1;end
 end
end
task heights;input integer set;begin
 for(m=0;m<16;m=m+1)begin
  dut.shown[m]=(m*13+set*31)%97;dut.peaks[m]=(m*7+set*23)%97;
  ref_dut.shown[m]=dut.shown[m];ref_dut.peaks[m]=dut.peaks[m];
 end
end endtask
task step;begin rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};end endtask
// One XGA frame: x/y are the overlay mapping (X*5/8) used by display_enhance.
task xga_frame;input smooth;begin
 for(yy=0;yy<768;yy=yy+1)for(xx=0;xx<1024;xx=xx+1)begin
  @(negedge clk);xga_x=xx;xga_y=yy;x=xx*5/8;y=yy*5/8;de=1;music=1;mode=2;step;
  rgb=smooth?{8'd40+xx[9:3],8'd60+yy[9:3],8'd90}:rng[23:0];
 end
 repeat(9)@(negedge clk);
end endtask
initial begin
 repeat(4)@(negedge clk);rst=0;
 // A
 for(n=0;n<3;n=n+1)begin
  heights(n);
  for(m=0;m<3;m=m+1)begin
   for(yy=0;yy<480;yy=yy+1)for(xx=0;xx<640;xx=xx+1)begin
    @(negedge clk);x=xx;y=yy;xga_x=xx;xga_y=yy;mode=m;de=1;music=1;step;rgb=rng[23:0];
    check_a=m<2;check_b=m==2;
   end
   repeat(9)@(negedge clk);check_a=0;check_b=0;
  end
 end
 // B
 f=$fopen("radial_rtl.hex","w");
 for(n=0;n<3;n=n+1)begin heights(n);dump=1;check_b=1;xga_frame(0);end
 check_b=0;dump=0;$fclose(f);
 if(boxed!=3*191*191)$fatal(1,"dumped %0d ring-box pixels",boxed);
 // Gates: music off, OFF mode and blanking leave the photo untouched.
 heights(1);
 @(negedge clk);xga_x=884-48;xga_y=628+14;x=xga_x*5/8;y=xga_y*5/8;mode=2;music=0;de=1;rgb=24'h123456;
 repeat(8)@(negedge clk);if(result!==24'h123456)$fatal(1,"music-off radial changed photo");
 music=1;de=0;repeat(8)@(negedge clk);if(result!==24'h123456)$fatal(1,"blanking radial changed photo");
 de=1;mode=0;repeat(8)@(negedge clk);if(result!==24'h123456)$fatal(1,"OFF radial changed photo");
 mode=2;repeat(8)@(negedge clk);if(result===24'h123456)$fatal(1,"radial ring missing");
 // C: same frame through the 3.0 renderer (left) and this one (right).
 heights(2);f=$fopen("radial_preview.hex","w");
 for(yy=528;yy<728;yy=yy+1)for(xx=784;xx<984;xx=xx+1)begin
  @(negedge clk);xga_x=xx;xga_y=yy;x=xx*5/8;y=yy*5/8;rgb={8'd40+xx[9:3],8'd60+yy[9:3],8'd90};
  repeat(7)@(negedge clk);$fwrite(f,"%h %h\n",reference_rgb,result);
 end
 $fclose(f);
 $display("SPECTRUM_BARS_EQUAL_3_0_RADIAL_XGA_BOX_ONLY_GATES_PASS");$finish;
end
endmodule
