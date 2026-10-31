`timescale 1ns/1ps
// 24x24 SimSun OSD in XGA space, all nine pages, three-clock latency:
// outside the panel the photo passes untouched; in_panel it is dimmed to 1/4
// or white/yellow ink; probed cells match the font ROM bit for bit.
// Also writes RTL previews ../docs/preview/osd_xga_page{4,6,7}.ppm.
module tb_osd_pipeline;
reg clk=0;always #5 clk=~clk;
reg rst=1;reg [9:0] x=0,y=0;reg [3:0] page=0;
reg signed [8:0] brightness=-256;reg [8:0] contrast=511;
reg signed [6:0] temperature=-64;
reg [23:0] rgb=0;wire [23:0] result;
text_layers #(.ENABLE_TEMPERATURE(1)) dut(
 .rgb(rgb),.de(1'b1),.x(x),.y(y),.page(page),.brightness(brightness),.contrast(contrast),
 .scale(5'd20),.transition(2'd2),.subtitle(2'd0),.bank(4'd3),.auto_enabled(1'b1),
 .error_code(8'd255),.osd_enable(1'b1),.subtitle_enable(1'b0),.scroll(10'd0),.out_rgb(result),
 .music_track(3'd2),.music_status(3'd2),.visual_mode(2'd2),.speed(2'd1),.speed_toast(1'b1),
 .audio_item(2'd3),.mute(1'b1),.music_enable(1'b1),.click_enable(1'b1),.visual_enable(1'b1),
 .temperature(temperature),.clk(clk),.rst(rst));
reg [23:0] font[0:1679];
reg [43:0] sent[0:2];   // {x,y,rgb} three clocks ago
reg [9:0] px,py;reg [23:0] bg;reg in_panel,sweep=0;
integer i,n,p,age=0,ink=0,yellow=0,probed=0,col,row,lx,ly,g,f;
// Expected glyph for the probed overview cells (row 0: "总" "3" "+").
function integer probe_glyph;input integer col,row;begin
 probe_glyph=-1;
 if(row==0)case(col)0:probe_glyph=20;6:probe_glyph=59;7:probe_glyph=66;endcase
end endfunction
always @(posedge clk)if(!rst && sweep)begin
 for(i=2;i>0;i=i-1)sent[i]=sent[i-1];
 sent[0]={x,y,rgb};age=age+1;
 #1;{px,py,bg}=sent[2];
 if(age>=3)begin
  in_panel=px>=12 && px<(page==6?864:576) && py>=12 && py<(page==6?336:48);
  if(!in_panel)begin
   if(result!==bg)$fatal(1,"page %0d (%0d,%0d) outside panel changed",page,px,py);
  end else if(result!=={2'b0,bg[23:18],2'b0,bg[15:10],2'b0,bg[7:2]})begin
   if(result===24'hffffff)ink=ink+1;
   else if(result===24'hffff00)begin
    yellow=yellow+1;
    if(page==6 || py>=42 || px>=24+4*24)$fatal(1,"page %0d (%0d,%0d) yellow outside label",page,px,py);
   end else $fatal(1,"page %0d (%0d,%0d) panel rgb %h",page,px,py,result);
  end
  if(page==6 && px>=24 && py>=18)begin
   col=(px-24)/24;row=(py-18)/24;lx=(px-24)%24;ly=(py-18)%24;g=probe_glyph(col,row);
   if(g>=0)begin
    probed=probed+1;
    if((result===24'hffffff)!==font[g*24+ly][23-lx])$fatal(1,"glyph %0d bit (%0d,%0d) mismatch",g,lx,ly);
   end
  end
 end
end
task check_cell;input integer col,row,want;begin
 @(negedge clk);x=24+col*24;y=18+row*24;repeat(2)@(negedge clk);
 if(dut.c!==want)$fatal(1,"overview cell (%0d,%0d) glyph %0d, expected %0d",col,row,dut.c,want);
end endtask
task preview;input [3:0] pg;input integer w,h;begin
 page=pg;sweep=0;
 if(pg==4)f=$fopen("../docs/preview/osd_xga_page4.ppm","w");
 else if(pg==6)f=$fopen("../docs/preview/osd_xga_page6.ppm","w");
 else f=$fopen("../docs/preview/osd_xga_page7.ppm","w");
 $fwrite(f,"P3\n%0d %0d\n255\n",w,h);
 for(n=0;n<w*h+3;n=n+1)begin
  @(negedge clk);x=n%w;y=n/w;rgb={8'd70+x[9:3],8'd110+y[8:2],8'd150};
  if(n>=3)$fwrite(f,"%0d %0d %0d\n",result[23:16],result[15:8],result[7:0]);
 end
 $fclose(f);
end endtask
initial begin
 $readmemh("../user_source/hdl_source/font24_rows.mem",font);
 repeat(5)@(negedge clk);rst=0;
 for(p=0;p<9;p=p+1)begin
  page=p;ink=0;yellow=0;age=0;sweep=1;
  for(n=0;n<1024*360;n=n+1)begin
   @(negedge clk);x=n%1024;y=n/1024;rgb=n*78923;
  end
  repeat(4)@(negedge clk);sweep=0;
  if(ink+yellow<300)$fatal(1,"page %0d has only %0d ink pixels",p,ink+yellow);
  $display("page %0d: white %0d yellow %0d",p,ink,yellow);
  if(p!=6 && yellow<100)$fatal(1,"page %0d label not highlighted",p);
 end
 if(probed!=3*576)$fatal(1,"probed %0d glyph pixels",probed);
 // Overview values: brightness -256 (row 1), contrast 511 (row 2),
 // error 255 (row 7), temperature -64 (row 12); glyph = D0 + digit.
 page=6;
 check_cell(4,1,dut.MINUS);check_cell(5,1,dut.D0+2);check_cell(6,1,dut.D0+5);check_cell(7,1,dut.D0+6);
 check_cell(5,2,dut.D0+5);check_cell(6,2,dut.D0+1);check_cell(7,2,dut.D0+1);
 check_cell(4,7,dut.D0+2);check_cell(5,7,dut.D0+5);check_cell(6,7,dut.D0+5);
 check_cell(4,12,dut.MINUS);check_cell(5,12,dut.D0);check_cell(6,12,dut.D0+6);check_cell(7,12,dut.D0+4);
 preview(4,600,64);preview(6,880,352);preview(7,600,64);
 $display("OSD_XGA_SIMSUN24_9_PAGES_PANEL_INK_GLYPH_EXACT_PASS");$finish;
end
endmodule
