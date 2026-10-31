`timescale 1ns/1ps
module tb_pll_clocks;
reg clk=0;always #10 clk=~clk;
reg rst=1;wire sd,mem,mem_phase,pixel,tmds,audio,a0,a1,l0,l1,l2;
sys_pll sys(clk,rst,sd,mem,mem_phase,l0);
video_pll vid(clk,rst,pixel,tmds,l1);
PLL_HDMI_AUDIO aud(clk,rst,l2,a0,a1,audio);
realtime t0,t1,t2,t3;
initial begin
 #100 rst=0;wait(l0 && l1 && l2);#1000;
 @(posedge sd);t0=$realtime;repeat(20)@(posedge sd);
 if($realtime-t0<199.8 || $realtime-t0>200.2)$fatal(1,"SD clock period");
 @(posedge mem);t0=$realtime;repeat(20)@(posedge mem);
 if($realtime-t0<239.8 || $realtime-t0>240.2)$fatal(1,"memory clock period");
 @(negedge mem);@(posedge mem_phase);t0=$realtime;
 @(negedge mem);@(posedge mem);t1=$realtime;
 if(t1-t0<11.98 || t1-t0>12.02)$fatal(1,"memory phase is not zero");
 @(posedge pixel);t0=$realtime;repeat(20)@(posedge pixel);
 if($realtime-t0<307.60 || $realtime-t0>307.80)$fatal(1,"XGA pixel period");
 @(posedge tmds);t0=$realtime;repeat(100)@(posedge tmds);
 if($realtime-t0<307.60 || $realtime-t0>307.80)$fatal(1,"XGA serializer period");
 @(posedge audio);t0=$realtime;repeat(10)@(posedge audio);
 if($realtime-t0<813.1 || $realtime-t0>813.5)$fatal(1,"audio period");
 $display("PLL_INTERNAL_FEEDBACK_100_83_65_325_12MHZ_PHASE_ZERO_PASS");$finish;
end
initial begin #1000000;$fatal(1,"PLL lock timeout");end
endmodule

