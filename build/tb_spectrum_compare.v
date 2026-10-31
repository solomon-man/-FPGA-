`timescale 1ns/1ps
module tb_spectrum_compare;
reg clk=0;always #5 clk=~clk;
reg rst=1,music=0,pv=0,fs=0;
reg signed [15:0] pcm=0;
integer n,k;reg [31:0] noise=32'h13579bdf;
audio_spectrum dut(.clk(clk),.rst(rst),.frame_start(fs),.de(1'b0),.rgb_in(24'd0),
 .x(10'd0),.y(10'd0),.mode(2'd0),.music_enable(music),.pcm_valid(pv),.pcm_left(pcm),.rgb_out());
audio_spectrum reference_dut(.clk(clk),.rst(rst),.frame_start(fs),.de(1'b0),.rgb_in(24'd0),
 .x(10'd0),.y(10'd0),.mode(2'd0),.music_enable(music),.pcm_valid(pv),.pcm_left(pcm),.rgb_out());
always @(negedge clk)if(!rst)begin
 for(k=0;k<16;k=k+1)begin
  if(dut.levels[k]!==reference_dut.levels[k] || dut.shown[k]!==reference_dut.shown[k] ||
     dut.peaks[k]!==reference_dut.peaks[k])$fatal(1,"RAM DFT differs from previous accumulator bin %d",k);
 end
 if(dut.sum_r!==reference_dut.sum_r || dut.sum_i!==reference_dut.sum_i)
  $fatal(1,"RAM DFT accumulator numeric mismatch");
end
initial begin
 repeat(5)@(negedge clk);rst=0;music=1;
 for(n=0;n<2200;n=n+1)begin
  noise={noise[30:0],noise[31]^noise[21]^noise[1]^noise[0]};
  @(negedge clk);pcm=noise[15:0];pv=1;fs=n%31==0;
  @(negedge clk);pv=0;fs=0;repeat(98)@(negedge clk);
  if(n==777)begin music=0;repeat(8)@(negedge clk);music=1;end
  if(n==1501)begin rst=1;repeat(5)@(negedge clk);rst=0;end
 end
 $display("RAM_DFT_PREVIOUS_VERSION_EXACT_ACCUMULATORS_NOISE_RESET_RESTART_PASS");$finish;
end
endmodule
config spectrum_compare_cfg;
 design work.tb_spectrum_compare;
 default liblist work;
 instance tb_spectrum_compare.reference_dut use spectrum_previous.audio_spectrum;
endconfig
