`timescale 1ns/1ps
// 3.0 pipelined level update vs the 2.0 audio_spectrum: identical levels,
// shown and peaks after every frame, tones, chords, noise and music on/off.
module tb_spectrum_levels3;
reg clk=0;always #5 clk=~clk;
reg rst=1,fs=0,music=1,pv=0;reg signed [15:0] pcm=0;
wire [23:0] a,b;
audio_spectrum dut(clk,rst,fs,1'b0,24'd0,10'd0,10'd0,2'd1,music,pv,pcm,a,10'd0,10'd0);
audio_spectrum_v20 reference(clk,rst,fs,1'b0,24'd0,10'd0,10'd0,2'd1,music,pv,pcm,b);
integer n,f,k,checks=0,nonzero=0;integer seed=7;real v;
task sample(input integer value);begin
 @(negedge clk);pcm=value;pv=1;@(negedge clk);pv=0;repeat(70)@(negedge clk);
end endtask
initial begin
 repeat(4)@(negedge clk);rst=0;
 for(f=0;f<14;f=f+1)begin
  if(f==9)begin music=0;repeat(4)@(negedge clk);music=1;end
  for(n=0;n<700;n=n+1)begin
   case(f%5)
    0:v=9000.0*$sin(6.283185307*(f+2)*n/512.0);
    1:v=6000.0*$sin(6.283185307*3*n/512.0)+5000.0*$sin(6.283185307*11*n/512.0);
    2:v=$random(seed)%30000;
    3:v=0;
    default:v=32000.0*$sin(6.283185307*7*n/512.0);
   endcase
   sample($rtoi(v));
   if(n%233==0)begin @(negedge clk);fs=1;@(negedge clk);fs=0;repeat(18)@(negedge clk);end // frames are >=18 clocks apart
  end
  repeat(8)@(negedge clk);fs=1;@(negedge clk);fs=0;repeat(18)@(negedge clk); // 3.0: shown/peaks update one bin per clock
  for(k=0;k<16;k=k+1)begin
   if(dut.levels[k]!==reference.levels[k] || dut.shown[k]!==reference.shown[k] || dut.peaks[k]!==reference.peaks[k])
    $fatal(1,"frame %0d bin %0d: %0d/%0d/%0d vs %0d/%0d/%0d",f,k,dut.levels[k],dut.shown[k],dut.peaks[k],
     reference.levels[k],reference.shown[k],reference.peaks[k]);
   if(dut.levels[k]!=0)nonzero=nonzero+1;
   checks=checks+1;
  end
 end
 if(nonzero<60)$fatal(1,"stimulus too quiet %0d",nonzero);
 $display("SPECTRUM3_PIPELINED_LEVELS_EQUAL_V20_%0d_BINS_PASS",checks);$finish;
end
endmodule
