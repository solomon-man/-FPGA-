`timescale 1ns/1ps
module tb_osd_pipeline;
reg clk=0;always #5 clk=~clk;
reg rst=1;reg [9:0] x=0,y=0;reg [3:0] page=0;
reg signed [8:0] brightness=-256;reg [8:0] contrast=511;
reg signed [6:0] temperature=-64;
reg [23:0] rgb=0;wire [23:0] legacy,pipelined;
reg [23:0] expected[0:2];integer i,n,p,age=0;
text_layers #(.ENABLE_TEMPERATURE(1)) ref_osd(
 .rgb(rgb),.de(1'b1),.x(x),.y(y),.page(page),.brightness(brightness),.contrast(contrast),
 .scale(5'd20),.transition(2'd2),.subtitle(2'd0),.bank(4'd3),.auto_enabled(1'b1),
 .error_code(8'd255),.osd_enable(1'b1),.subtitle_enable(1'b0),.scroll(10'd0),.out_rgb(legacy),
 .music_track(3'd2),.music_status(3'd2),.visual_mode(2'd2),.speed(2'd1),.speed_toast(1'b1),
 .audio_item(2'd3),.mute(1'b1),.music_enable(1'b1),.click_enable(1'b1),.visual_enable(1'b1),
 .temperature(temperature),.clk(clk),.rst(rst));
text_layers #(.ENABLE_TEMPERATURE(1),.PIPELINED_RENDER(1)) dut(
 .rgb(rgb),.de(1'b1),.x(x),.y(y),.page(page),.brightness(brightness),.contrast(contrast),
 .scale(5'd20),.transition(2'd2),.subtitle(2'd0),.bank(4'd3),.auto_enabled(1'b1),
 .error_code(8'd255),.osd_enable(1'b1),.subtitle_enable(1'b0),.scroll(10'd0),.out_rgb(pipelined),
 .music_track(3'd2),.music_status(3'd2),.visual_mode(2'd2),.speed(2'd1),.speed_toast(1'b1),
 .audio_item(2'd3),.mute(1'b1),.music_enable(1'b1),.click_enable(1'b1),.visual_enable(1'b1),
 .temperature(temperature),.clk(clk),.rst(rst));
always @(posedge clk)if(!rst)begin
 for(i=2;i>0;i=i-1)expected[i]=expected[i-1];
 expected[0]=legacy;age=age+1;
 #1;if(age>=3 && pipelined!==expected[2])$fatal(1,"OSD pipeline RGB mismatch at %d",age);
end
initial begin
 repeat(5)@(negedge clk);rst=0;
 for(p=0;p<9;p=p+1)begin
  page=p;
  for(n=0;n<640*240;n=n+1)begin
   @(negedge clk);x=n%640;y=n/640;rgb=n*78923;
  end
 end
 repeat(4)@(negedge clk);
 $display("OSD_PIPELINE_1382400_PIXELS_ALL_PAGES_EXACT_RGB_PASS");$finish;
end
endmodule
