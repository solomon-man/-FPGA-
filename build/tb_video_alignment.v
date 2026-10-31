`timescale 1ns/1ps
module tb_video_alignment;
reg clk=0;always #5 clk=~clk;
reg rst=1,hs=0,vs=0,de=0,valid=0;reg [23:0] rgb=0;reg [54:0] params=0;
wire oh,ov,od;wire [23:0] result;
reg [27:0] expected[0:16];integer i,n,age=0;reg [31:0] rng=32'h183bc492;
display_enhance dut(.clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),.display_valid(valid),.frame_start(1'b0),
 .rgb_in(rgb),.bank(4'd0),.auto_enabled(1'b0),.error_code(8'd0),.parameters(params),.alpha(8'd255),
 .reveal(10'd640),.pcm_valid(1'b0),.pcm_left(24'd0),.pcm_right(24'd0),.out_hs(oh),.out_vs(ov),.out_de(od),.rgb_out(result));
always @(posedge clk)if(!rst)begin
 for(i=16;i>0;i=i-1)expected[i]=expected[i-1];
 expected[0]={hs,vs,de,valid,(de && valid)?rgb:24'd0};age=age+1;
 #1;if(age>=17 && ({oh,ov,od}!==expected[16][27:25] ||
    (od && result!==expected[16][23:0])))$fatal(1,"video latency or RGB alignment failed age %d: %h %h",age,result,expected[16]);
end
initial begin
 params[19:11]=128;params[7:6]=3; // 30%, already resampled in the reader
 repeat(5)@(negedge clk);rst=0;
 for(n=0;n<2200000;n=n+1)begin
  @(negedge clk);hs=n%1344>=136;vs=n/1344%806>=6;
  de=n%1344>=296 && n%1344<1320 && n/1344%806>=35 && n/1344%806<803;
  valid=n>1000;rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};rgb=rng[23:0];
 end
 repeat(20)@(negedge clk);
 $display("XGA_DISPLAY_17_CLOCK_RGB_HS_VS_DE_ALIGNMENT_NO_DOUBLE_MASK_PASS");$finish;
end
endmodule
