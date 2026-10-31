`timescale 1ns/1ps
module tb_fit122;
reg clk=0;always #5 clk=~clk;
reg rst=1,load=0,valid=0,done=0,ack=0;reg [7:0] data=0;
wire ready,req,wen,wreq,error;wire [31:0] lba;wire [23:0] pixel;wire [7:0] err;
bmp_fit_read dut(.clk(clk),.rst(rst),.ready(ready),.scan_start(1'b0),
 .scan_start_sector(0),.scan_max_sector(0),.scan_target_count(4'd1),.scan_done(),
 .scan_found_valid(),.scan_found_sector(),.scan_found_total(),.load_start(load),.load_sector(0),
 .sd_init_done(1'b1),.state_code(),.bmp_width(16'd640),.bmp_height(16'd480),
 .write_req(wreq),.write_req_ack(ack),.sd_sec_read(req),.sd_sec_read_addr(lba),
 .sd_sec_read_data(data),.sd_sec_read_data_valid(valid),.sd_sec_read_end(done),
 .bmp_data_wr_en(wen),.bmp_data(pixel),.load_error(error),.bmp_error(err));
integer w,h,stride,offset,flen,fw,fh,px,py,pixels,requests;
integer address,i,x,y,sx,sy,cycles=0,last_pixel_cycle=-100,case_count=0;
reg busy=0,error_seen=0;reg [23:0] expected;
function [23:0] pattern;input integer xx,yy;
 begin pattern={8'(xx*7+yy*11),8'(yy),8'(xx)};end
endfunction
function [7:0] file_byte;input integer pos;integer row,col,bytecol;reg [23:0] rgb;
 begin
 file_byte=0;
 case(pos)
  0:file_byte=66;1:file_byte=77;
  2,3,4,5:file_byte=(flen>>((pos-2)*8))&255;
  10,11,12,13:file_byte=(offset>>((pos-10)*8))&255;
  14:file_byte=40;
  18,19,20,21:file_byte=(w>>((pos-18)*8))&255;
  22,23,24,25:file_byte=(h>>((pos-22)*8))&255;
  26:file_byte=1;28:file_byte=24;
  default:if(pos>=offset && pos<flen)begin
   row=(pos-offset)/stride;bytecol=(pos-offset)%stride;col=bytecol/3;
   rgb=pattern(col,row);
   if(bytecol<w*3)file_byte=(rgb>>((bytecol%3)*8))&255;
   else file_byte=8'hfe;
  end
 endcase
 end
endfunction
// Model the asynchronous writer retaining ACK/reset after request falls.
initial forever begin
 wait(wreq && !rst);repeat(3)@(negedge clk);ack=1;
 wait(!wreq);repeat(12)@(negedge clk);ack=0;
end
initial forever begin
 @(negedge clk);
 if(req && !rst)begin
  address=lba;requests=requests+1;busy=1;
  repeat(3)@(negedge clk);
  for(i=0;i<512;i=i+1)begin data=file_byte(address*512+i);valid=1;@(negedge clk);valid=0;@(negedge clk);end
  repeat(2)@(negedge clk);done=1;@(negedge clk);done=0;
  repeat(4)@(negedge clk);busy=0;
 end
end
always @(posedge clk)begin
 cycles=cycles+1;
 if(!rst)begin
  if(error)error_seen=1;
  if(wen)begin
   if(ack)$fatal(1,"Pixel emitted while writer FIFO held in reset");
   if(cycles-last_pixel_cycle<64)$fatal(1,"Output pacing violated");last_pixel_cycle=cycles;
   x=pixels%640;y=pixels/640;expected=0;
   if(x>=px && x<px+fw && y>=py && y<py+fh)begin
    sx=(x-px)*w/fw;sy=(y-py)*h/fh;expected=pattern(sx,sy);
   end
   if(pixels>=307200 || pixel!==expected)$fatal(1,"FIT %dx%d pixel(%d,%d) got %h expected %h",w,h,x,y,pixel,expected);
   pixels=pixels+1;
  end
 end
end
task run_case;input integer ww,hh,off;
 begin
  wait(!busy);@(negedge clk);rst=1;load=0;
  w=ww;h=hh;offset=off;stride=((w*3+3)/4)*4;flen=offset+stride*h;
  if(w*480>=h*640)begin fw=640;fh=h*640/w;if(fh<1)fh=1;end
  else begin fh=480;fw=w*480/h;if(fw<1)fw=1;end
  px=(640-fw)/2;py=(480-fh)/2;pixels=0;requests=0;error_seen=0;
  repeat(5)@(negedge clk);rst=0;repeat(3)@(negedge clk);
  load=1;@(negedge clk);load=0;wait(!ready);wait(ready);repeat(3)@(negedge clk);
  if(error_seen || pixels!=307200)$fatal(1,"Incomplete fit frame %dx%d pixels%d error%h",w,h,pixels,err);
  if(requests!=(flen+511)/512)$fatal(1,"Nonsequential/redundant sector requests");
  case_count=case_count+1;$display("ASPECT_FIT_CASE_PASS %dx%d -> %dx%d padding %d,%d",w,h,fw,fh,px,py);
 end
endtask
task reject_case;input integer ww,hh,declared;
 begin
  wait(!busy);@(negedge clk);rst=1;load=0;
  w=ww;h=hh;offset=54;stride=((w*3+3)/4)*4;flen=declared;pixels=0;requests=0;error_seen=0;
  repeat(5)@(negedge clk);rst=0;repeat(3)@(negedge clk);
  load=1;@(negedge clk);load=0;wait(!ready);wait(ready);repeat(3)@(negedge clk);
  if(!error_seen || pixels!=0 || wreq || err!=8'h31)$fatal(1,"Invalid geometry/payload accepted");
 end
endtask
initial begin
 run_case(641,479,54); // downscale, odd width, BMP padding, sector-spanning pixels
 run_case(3,5,1024); // upscale portrait, extended header, repeated rows
 run_case(1,1,54); // smallest image, both axes upsample
 run_case(1920,1080,54); // landscape with top/bottom letterbox
 run_case(4096,1,54); // extreme aspect and maximum row address
 reject_case(0,480,921654);
 reject_case(4097,1,20000);
 reject_case(640,-480,921654);
 reject_case(640,480,100);
 $display("BMP_ASPECT_FIT_INVALID_GEOMETRY_PAYLOAD_REJECTED_PASS");
 $display("BMP_ASPECT_FIT_FULL_PIXELS_PADDING_UP_DOWN_EXTREME_PASS");$finish;
end
initial begin #2000000000;$fatal(1,"Aspect fit timeout");end
endmodule
