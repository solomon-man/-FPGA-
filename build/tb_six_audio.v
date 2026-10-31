`timescale 1ns/1ps
module tb_six_audio;
reg clk=0;always #5 clk=~clk;
reg rst=1,valid=0,mute=0,music=1,click=0,display_valid=0;
reg [2:0] bank=0;
reg [23:0] li=24'd2000000,ri=-24'sd2000000;
wire [23:0] lo,ro;
audio_mix122 #(.CLICK_SAMPLES(100),.BANK_BITS(3)) dut(clk,rst,valid,li,ri,mute,music,click,bank,display_valid,lo,ro);
task tick;begin @(negedge clk);end endtask
task sample;begin valid=1;tick;valid=0;tick;end endtask
integer i,a,b,c;
initial begin
 repeat(3)tick;rst=0;tick;
 if(lo!==li||ro!==ri)$fatal(1,"Default music not bit exact");
 click=1;display_valid=1;tick;tick;if(dut.remaining!=0)$fatal(1,"First image beeped");
 bank=4;tick;tick;if(dut.remaining!=100)$fatal(1,"Commit prompt missing");
 for(a=0;a<2;a=a+1)for(b=0;b<2;b=b+1)begin
  mute=a;music=b;#1;
  if(mute)begin if(lo!=0||ro!=0)$fatal(1,"Master mute");end
  else if(music)begin if($signed(lo)!=2750000||$signed(ro)!=-1250000)$fatal(1,"Stereo mix");end
  else if(lo!=750000||ro!=750000)$fatal(1,"Prompt only");
 end
 mute=0;music=1;li=24'h7fffff;ri=24'h7fffff;#1;
 if(lo!=24'h7fffff||ro!=24'h7fffff)$fatal(1,"Positive saturation");
 repeat(24)sample;li=24'h800000;ri=24'h800000;#1;
 if(lo!=24'h800000||ro!=24'h800000)$fatal(1,"Negative saturation");
 mute=1;repeat(76)sample;if(dut.remaining!=0)$fatal(1,"Prompt duration under mute");
 mute=0;music=0;#1;if(lo!=0||ro!=0)$fatal(1,"Prompt did not stop");
 bank=5;tick;tick;click=0;tick;tick;if(dut.remaining!=0||lo!=0)$fatal(1,"Click off");
 for(a=0;a<2;a=a+1)for(b=0;b<2;b=b+1)begin
  mute=a;music=b;#1;
  if(lo!==(a||!b?24'd0:li)||ro!==(a||!b?24'd0:ri))$fatal(1,"Music only and mute combinations");
 end
 click=1;tick;tick;if(dut.remaining!=0)$fatal(1,"Enable replayed old prompt");
 bank=0;display_valid=0;tick;tick;if(dut.remaining!=0)$fatal(1,"Invalid image beeped");
 $display("SIX_BANK_4_5_AUDIO_CLICK_MIX_PASS");$finish;
end
endmodule
