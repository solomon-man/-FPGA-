`timescale 1ns/1ps
// VISUAL=WAVE through display_enhance at XGA timing: 17-clock alignment,
// only the bottom band changes, mute decays to dots, OFF/music-off bypass.
module tb_wave_display3;
reg clk=0;always #5 clk=~clk;
localparam integer LINE=1344,FRAME=1344*806;
reg rst=1,hs=0,vs=0,de=0,valid=0,fs=0,pv=0;reg [23:0] rgb=0,left=0,right=0;reg [54:0] params=0;
wire oh,ov,od;wire [23:0] result;
display_enhance dut(.clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),.display_valid(valid),.frame_start(fs),
 .rgb_in(rgb),.bank(4'd0),.auto_enabled(1'b0),.error_code(8'd0),.parameters(params),.alpha(8'd255),
 .reveal(10'd640),.pcm_valid(pv),.pcm_left(left),.pcm_right(right),
 .out_hs(oh),.out_vs(ov),.out_de(od),.rgb_out(result));
reg [27:0] expected[0:16];reg [9:0] line_d[0:16];
integer i,n,age=0,frame_index=0,white=0,changed=0,phase=0;real t;reg [31:0] rng=32'h51a7e3c9;
always @(posedge clk)if(!rst)begin
 for(i=16;i>0;i=i-1)begin expected[i]=expected[i-1];line_d[i]=line_d[i-1];end
 expected[0]={hs,vs,de,valid,(de && valid)?rgb:24'd0};line_d[0]=n/LINE%806;age=age+1;
 #1;
 if(age>=17)begin
  if({oh,ov,od}!==expected[16][27:25])$fatal(1,"sync alignment failed at age %0d",age);
  if(od && result!==expected[16][23:0])begin
   changed=changed+1;
   // Band y=448..479 of the 640x480 overlay space is XGA active line 717..767.
   if(line_d[16]<35+716)$fatal(1,"pixel changed on line %0d, outside the wave band",line_d[16]);
   if(result===24'hffffff)white=white+1;
  end
 end
end
task check_frame;begin
 case(frame_index)
  1,6:if(white<5000 || changed<40000)$fatal(1,"loud wave frame %0d white=%0d changed=%0d",frame_index,white,changed);
  2:if(white==0 || white>1500 || changed<40000)$fatal(1,"muted dots white=%0d changed=%0d",white,changed);
  3,4:if(changed!=0)$fatal(1,"bypass frame %0d changed %0d pixels",frame_index,changed);
 endcase
 $display("frame %0d: white %0d changed %0d",frame_index,white,changed);
 white=0;changed=0;
end endtask
initial begin
 params[19:11]=128;params[7:6]=3;params[3:2]=3;params[31]=1;
 repeat(5)@(negedge clk);rst=0;
 for(n=0;n<FRAME*7+LINE*40;n=n+1)begin
  @(negedge clk);
  if(n%FRAME==0 && n!=0)begin
   check_frame;frame_index=frame_index+1;
   case(frame_index)
    2:params[30]=1;                 // mute
    3:begin params[30]=0;params[3:2]=0;end  // VISUAL OFF
    4:begin params[3:2]=3;params[31]=0;end  // music disabled
    5:params[31]=1;
   endcase
  end
  hs=n%LINE>=136;vs=n/LINE%806>=6;
  de=n%LINE>=296 && n%LINE<1320 && n/LINE%806>=35 && n/LINE%806<803;
  valid=n>1000;rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};rgb=rng[23:0];
  // Snapshot at every frame start; while muted, twelve more in vblank.
  fs=n%FRAME==0 || (frame_index==2 && n%FRAME>=22000 && n%FRAME<46000 && n%FRAME%2000==0);
  pv=n%16==0;
  if(pv)begin
   phase=phase+1;t=29000.0*$sin(6.283185307*phase/37.0);
   left=$rtoi(t)<<<8;right=-($rtoi(t)<<<8);
  end
 end
 $display("WAVE3_XGA_DISPLAY_17_CLOCK_BAND_ONLY_MUTE_DOTS_BYPASS_RESTART_PASS");$finish;
end
endmodule
