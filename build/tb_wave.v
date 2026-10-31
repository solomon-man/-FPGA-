`timescale 1ns/1ps
module tb_wave;
reg clk=0;always #20 clk=~clk;
reg rst=1,vs=1,de=0,valid=0,enable=1;
reg [9:0] x=0;reg [15:0] sample=16'h4000;
wire [23:0] rgb;wire active;
promax_audio_waveform #(.DECIMATE(1)) dut(.clk(clk),.rst_n(~rst),.vsync(vs),
 .de(de),.rgb_in(24'h123456),.pixel_x(x),.enable(enable),.pcm_tap_valid(valid),
 .pcm_tap_left(sample),.rgb_out(rgb),.waveform_active(active));
integer n;
initial begin
 repeat(4) @(negedge clk);rst=0;vs=0;
 repeat(2) @(negedge clk);vs=1;valid=1;
 repeat(32) @(negedge clk);valid=0;
 if(dut.capture_count!=32) $fatal(1,"PCM sample capture incomplete");
 vs=0;repeat(2) @(negedge clk);vs=1;
 if(!dut.display_valid) $fatal(1,"Waveform bank was not published");
 for(n=0;n<416;n=n+1) begin
  de=1;@(negedge clk);de=0;@(negedge clk);
 end
 de=1;x=64;#1;
 if(rgb!==24'h20ff90 || !active) $fatal(1,"PCM waveform was not drawn at expected amplitude");
 enable=0;#1;if(rgb!==24'h123456 || active) $fatal(1,"Waveform bypass altered image");
 $display("AUDIO_WAVEFORM_CAPTURE_AMPLITUDE_BYPASS_PASS");$finish;
end
initial begin #100000;$fatal(1,"Waveform timeout");end
endmodule
