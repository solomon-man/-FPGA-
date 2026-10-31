`timescale 1ns/1ps
// EARLY_XY=1 (x/y/de one clock ahead) must match EARLY_XY=0 pixel for pixel,
// including blanking gaps, for every page and the speed toast.
module tb_text_early_equiv;
reg clk=0;always #5 clk=~clk;
reg rst=1;reg [9:0] xe=0,ye=0,x=0,y=0;reg dee=0,de=0;reg [3:0] page=0;reg toast=0;
reg [23:0] rgb=0;wire [23:0] ref_rgb,dut_rgb;
always @(posedge clk)begin x<=xe;y<=ye;de<=dee;end
`define TL_PORTS .rgb(rgb),.de(de),.x(x),.y(y),.page(page),.brightness(-9'sd37),.contrast(9'd300), \
 .scale(5'd17),.transition(2'd1),.subtitle(2'd0),.bank(4'd9),.auto_enabled(1'b1), \
 .error_code(8'd65),.osd_enable(1'b1),.subtitle_enable(1'b0),.scroll(10'd0), \
 .music_track(3'd3),.music_status(3'd4),.visual_mode(2'd3),.speed(2'd2),.speed_toast(toast), \
 .audio_item(2'd2),.mute(1'b0),.music_enable(1'b1),.click_enable(1'b0),.visual_enable(1'b1), \
 .temperature(-7'sd12),.clk(clk),.rst(rst)
text_layers #(.ENABLE_TEMPERATURE(1)) ref_m(`TL_PORTS,.out_rgb(ref_rgb));
text_layers #(.ENABLE_TEMPERATURE(1),.EARLY_XY(1)) dut(`TL_PORTS,.out_rgb(dut_rgb),
 .de_early(dee),.x_early(xe),.y_early(ye));
integer p,i,j,checked=0,diff_px=0;
always @(posedge clk)if(!rst)begin
 checked=checked+1;
 if(ref_rgb!==dut_rgb)$fatal(1,"page %0d mismatch ref=%h dut=%h at x=%0d y=%0d",page,ref_rgb,dut_rgb,x,y);
 if(ref_rgb===24'hffffff || ref_rgb===24'hffff00)diff_px=diff_px+1;
end
initial begin
 repeat(4)@(posedge clk);rst<=0;
 for(p=0;p<10;p=p+1)begin
  page<=p==9?0:p;toast<=p==9;
  for(j=0;j<360;j=j+1)begin
   for(i=0;i<900;i=i+1)begin @(posedge clk);dee<=i<880;xe<=i<880?i:0;ye<=j;rgb<=$random;end
  end
 end
 if(diff_px<1000)$fatal(1,"OSD produced too few ink pixels (%0d)",diff_px);
 $display("TEXT_LAYERS_EARLY_XY_EQUIVALENT_PASS cycles=%0d ink_pixels=%0d",checked,diff_px);
 $finish;
end
endmodule
