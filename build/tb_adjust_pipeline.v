`timescale 1ns/1ps
module tb_adjust_pipeline;
reg clk=0;always #5 clk=~clk;
reg rst=1;reg [23:0] rgb=0;reg signed [8:0] brightness=0;reg [8:0] contrast=128;
reg signed [6:0] temperature=0;wire [23:0] expected_rgb,actual;
reg [23:0] q[0:2];integer i,n,age=0;reg [31:0] rng=32'h138dead7;
runtime_adjust #(.ENABLE_TEMPERATURE(1)) ref_dut(rgb,brightness,contrast,expected_rgb,temperature);
runtime_adjust_pipeline dut(clk,rst,rgb,brightness,contrast,temperature,actual);
always @(posedge clk)if(!rst)begin
 for(i=2;i>0;i=i-1)q[i]=q[i-1];q[0]=expected_rgb;age=age+1;
 #1;if(age>=3 && actual!==q[2])$fatal(1,"adjust exact RGB mismatch %h vs %h",actual,q[2]);
end
initial begin
 repeat(5)@(negedge clk);rst=0;
 for(n=0;n<150000;n=n+1)begin
  @(negedge clk);rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};rgb=rng[23:0];
  brightness=rng[31:23];contrast=rng[14:6];temperature=rng[6:0];
 end
 repeat(5)@(negedge clk);
 $display("ADJUST_PIPELINE_150000_EXACT_RGB_SIGNED_SATURATION_PASS");$finish;
end
endmodule
