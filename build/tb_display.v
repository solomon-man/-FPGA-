`timescale 1ns/1ps
module tb_display;
reg clk=0;always #5 clk=~clk;
reg rst=1,hs=0,vs=0,de=0,fs=0;reg [23:0] rgb=0;
reg [54:0] params=55'h5000040080;
wire oh,ov,od;wire [23:0] result;
display_enhance dut(.clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),.display_valid(1'b1),
 .frame_start(fs),.rgb_in(rgb),.bank(4'd0),.auto_enabled(1'b0),.error_code(8'd0),
 .parameters(params),.alpha(8'd255),.reveal(10'd640),.pcm_valid(1'b0),.pcm_left(24'd0),
 .out_hs(oh),.out_vs(ov),.out_de(od),.rgb_out(result));
reg [23:0] queue_rgb[0:3];reg [3:0] queue_de,queue_vs,queue_hs;
integer i,j,cycles=0,changed=0;
reg test_identity=1;
integer expected_temperature=0;
function [23:0] colored;
 input [23:0] p;input integer t;
 integer r,b;
 begin
  r=p[23:16]+t;b=p[7:0]-t;
  if(r<0)r=0;else if(r>255)r=255;
  if(b<0)b=0;else if(b>255)b=255;
  colored={r[7:0],p[15:8],b[7:0]};
 end
endfunction
always @(posedge clk)begin
 if(!rst)begin
  for(i=3;i>0;i=i-1)queue_rgb[i]=queue_rgb[i-1];
  queue_rgb[0]=colored(rgb,expected_temperature);queue_de={queue_de[2:0],de};queue_vs={queue_vs[2:0],vs};queue_hs={queue_hs[2:0],hs};
  cycles=cycles+1;
  #1;
  if(cycles>4)begin
   if(od!==queue_de[3] || ov!==queue_vs[3] || oh!==queue_hs[3])$fatal(1,"Timing alignment");
   if(test_identity && od && result!==queue_rgb[3])$fatal(1,"Default changed RGB %h %h",result,queue_rgb[3]);
   if(!test_identity && od && result!==queue_rgb[3])changed=changed+1;
  end
 end
end
task picture;
 begin
  @(negedge clk);vs=0;de=0;fs=1;
  repeat(8)@(negedge clk);fs=0;vs=1;
  for(j=0;j<480;j=j+1)begin
   for(integer k=0;k<640;k=k+1)begin
    @(negedge clk);de=1;rgb={k[7:0],j[7:0],8'hb7};hs=k[0];
   end
   @(negedge clk);de=0;repeat(8)@(negedge clk);
  end
  repeat(8)@(negedge clk);
 end
endtask
initial begin
 repeat(5)@(negedge clk);rst=0;
 picture();picture();
 expected_temperature=48;params[53:47]=7'd48;picture();
 expected_temperature=-48;params[53:47]=-7'sd48;picture();
 expected_temperature=0;params[53:47]=0;picture();
 $display("DISPLAY_TEMPERATURE_FULL_FRAMES_WARM_COLD_NEUTRAL_PIPELINE_PASS");
 if(!dut.scaler.ready)$fatal(1,"No complete thumbnail");
 test_identity=0;params[10:8]=6;params[1]=1;picture();
 if(changed<100)$fatal(1,"Overview not rendered");
 test_identity=1;params=47'h5000040080;picture();
 // The selected music PCM feeds the spectrum for both test and SD tracks.
 test_identity=0;params[43:41]=1;params[31]=1;params[3:2]=1;picture();
 if(dut.spectrum.music_enable!==1)$fatal(1,"SD music visual disabled");
 params[43:41]=0;#1;if(dut.spectrum.music_enable!==1)$fatal(1,"Test visual gating");
 $display("DISPLAY_IDENTITY_OSD_FADE_CONTRAST_PASS");$finish;
end
initial begin #50000000;$fatal(1,"Display timeout");end
endmodule
