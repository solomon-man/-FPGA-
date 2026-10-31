from pathlib import Path
b=Path(r'G:\ANLU_Project\digital photo frame3.0\build')
(b/'tb_render_pipeline.v').write_text('''`timescale 1ns/1ps
module tb_render_pipeline;
reg clk=0;always #5 clk=~clk;
reg rst=1,de=0,music=0;reg [9:0] x=0,y=0;reg [1:0] mode=0;
reg [23:0] rgb=0;wire [23:0] reference_rgb,result;
reg [23:0] expected[0:6];integer age=0,i,n,m,xx,yy;
reg [31:0] rng=32'h9137cdfe;
audio_spectrum ref_dut(clk,rst,1'b0,de,rgb,x,y,mode,music,1'b0,16'd0,reference_rgb);
audio_spectrum #(.PIPELINED_RENDER(1)) dut(clk,rst,1'b0,de,rgb,x,y,mode,music,1'b0,16'd0,result);
always @(posedge clk)begin
 if(rst)begin age=0;for(i=0;i<7;i=i+1)expected[i]=0;end
 else begin
  for(i=6;i>0;i=i-1)expected[i]=expected[i-1];
  expected[0]=reference_rgb;age=age+1;
  #1;if(age>=7 && result!==expected[6])$fatal(1,"render mismatch x=%d y=%d mode=%d expected %h actual %h",x,y,mode,expected[6],result);
 end
end
initial begin
 repeat(4)@(negedge clk);rst=0;
 for(n=0;n<3;n=n+1)begin
  for(m=0;m<16;m=m+1)begin
   ref_dut.shown[m]=(m*13+n*31)%128;ref_dut.peaks[m]=(m*7+n*23)%128;
   dut.shown[m]=(m*13+n*31)%128;dut.peaks[m]=(m*7+n*23)%128;
  end
  for(m=0;m<4;m=m+1)begin
   for(yy=0;yy<480;yy=yy+1)for(xx=0;xx<640;xx=xx+1)begin
    @(negedge clk);x=xx;y=yy;mode=m;de=1;music=1;
    rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};rgb=rng[23:0];
   end
   repeat(9)@(negedge clk);
  end
 end
 repeat(20)begin @(negedge clk);de=0;music=0;rgb=rgb+345;end
 $display("SPECTRUM_PIPELINE_3686400_PIXELS_EXACT_RGB_CIRCLE_BARS_PASS");$finish;
end
endmodule
''')
(b/'test_render_pipeline.do').write_text('''onerror {quit -code 1 -force}
vlib work_render_pipeline
vmap work work_render_pipeline
vlog -sv ../user_source/hdl_source/audio_spectrum.v tb_render_pipeline.v
vsim -novopt work.tb_render_pipeline
onfinish stop
run -all
quit -code 0 -force
''')
