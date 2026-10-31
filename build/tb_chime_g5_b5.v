`timescale 1ns/1ps
module tb_chime_g5_b5;
reg clk=0;always #5 clk=~clk;
reg rst=1,valid=0,display_valid=0;
reg [1:0] bank=0;
wire [23:0] left_out,right_out;
audio_mix122 #(.CLICK_SAMPLES(4800)) dut(
 .clk(clk),.rst(rst),.sample_valid(valid),.left_in(24'd0),.right_in(24'd0),
 .mute(1'b0),.music_enable(1'b0),.click_enable(1'b1),.bank(bank),
 .display_valid(display_valid),.left_out(left_out),.right_out(right_out));
integer i,g_edges=0,b_edges=0;
reg prev_g=0,prev_b=0;
integer g_phase=0,b_phase=0;
reg signed [24:0] expected;
initial begin
 repeat(3)@(negedge clk);rst=0;display_valid=1;
 repeat(2)@(negedge clk);
 if(left_out!==0)$fatal(1,"Initial image must be silent");
 bank=1;@(negedge clk);
 for(i=0;i<4800;i=i+1)begin
  expected=(g_phase<32768?375000:-375000)+(b_phase<32768?375000:-375000);
  if($signed(left_out)!==expected || left_out!==right_out)$fatal(1,"Two simultaneous voices mismatch at %d",i);
  // Clock without a sample must not advance either voice.
  @(negedge clk);
  if(dut.phase_g5!==g_phase[15:0] || dut.phase_b5!==b_phase[15:0])$fatal(1,"DDS advanced without sample");
  valid=1;@(negedge clk);valid=0;
  g_phase=(g_phase+1070)%65536;b_phase=(b_phase+1349)%65536;
  if(!prev_g && dut.phase_g5[15])g_edges=g_edges+1;
  if(!prev_b && dut.phase_b5[15])b_edges=b_edges+1;
  prev_g=dut.phase_g5[15];prev_b=dut.phase_b5[15];
 end
 if(g_edges<78 || g_edges>79 || b_edges<98 || b_edges>99)$fatal(1,"Wrong frequencies %d %d",g_edges,b_edges);
 if(dut.remaining!==0 || left_out!==0 || right_out!==0)$fatal(1,"Prompt did not end at 100 ms");
 $display("G5_B5_SIMULTANEOUS_FREQUENCY_SAMPLE_GATING_DURATION_PASS");$finish;
end
endmodule
