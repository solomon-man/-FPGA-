`timescale 1ns/1ps
// 3.0 level history: LOG_SCALE=0 must equal the v0.27 audio_ring_levels
// frame by frame; LOG_SCALE=1 must follow 4*log2(peak)-31 (1.5 dB steps);
// enable=0 must blank and restart the history.
module tb_wave_levels3;
reg clk=0;always #5 clk=~clk;
reg rst=1,en=1,fs=0,pv=0;reg signed [15:0] left=0,right=0;reg [6:0] index=0;
wire [4:0] lin_h,log_h,ref_h;
audio_wave_levels #(.LOG_SCALE(0)) lin(.clk(clk),.rst(rst),.enable(1'b1),.frame_start(fs),.pcm_valid(pv),
 .pcm_left(left),.pcm_right(right),.bar_index(index[5:0]),.bar_height(lin_h));
audio_wave_levels #(.LOG_SCALE(1)) logd(.clk(clk),.rst(rst),.enable(en),.frame_start(fs),.pcm_valid(pv),
 .pcm_left(left),.pcm_right(right),.bar_index(index[5:0]),.bar_height(log_h));
audio_ring_levels #(.BAR_COUNT(40)) reference(.clk(clk),.rst(rst),.frame_start(fs),.pcm_valid(pv),
 .pcm_left(left),.pcm_right(right),.bar_index(index),.bar_height(ref_h));
integer f,n,count,kind,i,a,lvl,previous,checks=0,nonzero=0;integer seed=32'h3a17;real model;
task sample(input integer l,input integer r);begin
 @(negedge clk);left=l;right=r;pv=1;@(negedge clk);pv=0;repeat(6)@(negedge clk);
end endtask
task frame;begin
 repeat(4)@(negedge clk);fs=1;@(negedge clk);fs=0;repeat(48)@(negedge clk);
end endtask
function integer amplitude(input integer kind,input integer n);
 integer r;
 begin
  r=$random(seed);
  case(kind)
   0:amplitude=0;
   2:amplitude=r%32768;
   3:amplitude=r%600;
   4:amplitude=(n*37)%32768-16384;
   5:amplitude=(n%97==0)?-32768:r%(1<<(n/64%16));
   default:amplitude=r%9000;
  endcase
 end
endfunction
initial begin
 repeat(4)@(negedge clk);rst=0;
 // Reference equivalence over silence, pauses, full scale, quiet, ramps.
 for(f=0;f<320;f=f+1)begin
  kind=f%7;count=kind==1?0:$unsigned($random(seed))%1500;
  for(n=0;n<count;n=n+1)begin
   a=amplitude(kind,n);
   if(kind==6)sample(0,a);else sample(a,(f%3==0)?-a:a/2);
  end
  frame;
  for(i=0;i<40;i=i+1)begin
   index=i;#1;
   if(lin_h!==ref_h)$fatal(1,"linear history differs from v0.27: frame %0d bar %0d %0d/%0d",f,i,lin_h,ref_h);
   if(ref_h!=0)nonzero=nonzero+1;
   checks=checks+1;
  end
 end
 if(nonzero<2000)$fatal(1,"equivalence stimulus too quiet: %0d",nonzero);
 $display("WAVE3_LINEAR_LEVELS_EQUAL_V027_%0d_BARS_PASS",checks);
 // dB scale: 0 below -42 dBFS, 28 from -1.2 dBFS, monotonic, within 1.5 steps.
 previous=0;
 for(a=0;a<=32768;a=a+1)begin
  lvl=logd.level(a);
  if(lvl<previous)$fatal(1,"log level not monotonic at %0d",a);
  previous=lvl;
  if(a<256 && lvl!=0)$fatal(1,"log floor at %0d",a);
  if(a>=28672 && lvl!=28)$fatal(1,"log ceiling at %0d",a);
  if(a>=256 && a<28672)begin
   model=4.0*$ln(a)/$ln(2.0)-31.0;
   if(model-lvl<0.0 || model-lvl>=1.5)$fatal(1,"log level %0d for %0d, model %f",lvl,a,model);
  end
 end
 $display("dBFS  linear  log: -40 %0d %0d, -30 %0d %0d, -20 %0d %0d, -10 %0d %0d, -3 %0d %0d",
  lin.level(328),logd.level(328),lin.level(1036),logd.level(1036),lin.level(3277),logd.level(3277),
  lin.level(10362),logd.level(10362),lin.level(23197),logd.level(23197));
 if(lin.level(3277)!=6 || logd.level(3277)!=15)$fatal(1,"-20 dBFS mapping");
 $display("WAVE3_LOG_SCALE_1P5DB_STEPS_MINUS42_TO_0DBFS_PASS");
 // Gate: disabling blanks at once; re-enabling restarts from an empty history.
 for(n=0;n<1400;n=n+1)sample(30000,-30000);
 frame;index=39;#1;if(log_h<26)$fatal(1,"loud newest bar %0d",log_h);
 en=0;@(negedge clk);
 for(i=0;i<40;i=i+1)begin index=i;#1;if(log_h!==0)$fatal(1,"disabled bar %0d not blank",i);end
 for(n=0;n<100;n=n+1)sample(30000,30000);
 en=1;frame;
 for(i=0;i<40;i=i+1)begin index=i;#1;if(log_h!==0)$fatal(1,"history leaked across disable at %0d",i);end
 for(n=0;n<64;n=n+1)sample(30000,30000);
 frame;index=39;#1;if(log_h<26)$fatal(1,"restart newest %0d",log_h);
 index=37;#1;if(log_h!==0)$fatal(1,"restart filled older bars");
 // Silence: every frame falls by at most 3 steps, reaching zero.
 previous=28;index=39;
 for(f=0;f<12;f=f+1)begin
  for(n=0;n<800;n=n+1)sample(0,0);
  frame;#1;
  if(log_h>previous || (previous>3 && log_h<previous-3))$fatal(1,"decay step %0d->%0d",previous,log_h);
  previous=log_h;
 end
 if(log_h!=0)$fatal(1,"silence did not reach zero");
 $display("WAVE3_ENABLE_GATE_BLANK_RESTART_DECAY_PASS");
 $finish;
end
initial begin #200000000;$fatal(1,"timeout");end
endmodule
