`timescale 1ns/1ps
module tb_bmp_full;
reg clk=0;always #5 clk=~clk;
reg rst=1,load_start=0,valid=0,sec_end=0,ack=0;
reg [7:0] data=0;
wire ready,wr_req,wr_en,load_error;
wire [23:0] pixel;wire [7:0] error_code;
integer emitted=0,k,byte_no,sector_no,bad_header=0;
integer offset=54,length=921654;
bmp_read dut(.clk(clk),.rst(rst),.ready(ready),.scan_start(1'b0),
 .scan_start_sector(32'd0),.scan_max_sector(32'd131071),.scan_target_count(3'd4),
 .scan_done(),.scan_found_valid(),.scan_found_sector(),.scan_found_total(),
 .load_start(load_start),.load_sector(32'd0),.sd_init_done(1'b1),.state_code(),
 .bmp_width(16'd640),.bmp_height(16'd480),.write_req(wr_req),.write_req_ack(ack),
 .sd_sec_read(),.sd_sec_read_addr(),.sd_sec_read_data(data),.sd_sec_read_data_valid(valid),
 .sd_sec_read_end(sec_end),.bmp_data_wr_en(wr_en),.bmp_data(pixel),
 .load_error(load_error),.bmp_error(error_code));
function [7:0] file_byte;
 input integer p;
 integer pix,channel;
 begin
  case(p)
   0:file_byte="B";1:file_byte="M";
   2:file_byte=length;3:file_byte=length>>8;4:file_byte=length>>16;5:file_byte=length>>24;
   10:file_byte=offset;11:file_byte=offset>>8;12:file_byte=offset>>16;13:file_byte=offset>>24;
   14:file_byte=40;
   18:file_byte=8'h80;19:file_byte=2;22:file_byte=8'he0;23:file_byte=1;
   26:file_byte=bad_header?2:1;28:file_byte=24;
   default:begin
    if(p>=offset && p<offset+921600) begin
      pix=(p-offset)/3;channel=(p-offset)%3;
      case(channel)
       0:file_byte=pix;1:file_byte=pix>>8;2:file_byte=pix>>16;
      endcase
    end else file_byte=0;
   end
  endcase
 end
endfunction
always @(posedge clk) begin
 if(rst) emitted=0;
 else if(wr_en) begin
  if(pixel!==emitted[23:0]) $fatal(1,"BGR decode/order failed pixel %d got %h",emitted,pixel);
  emitted=emitted+1;
 end
end
task send_sector;
 input integer sector;
 begin
  for(k=0;k<512;k=k+1) begin
   @(negedge clk);valid=1;data=file_byte(sector*512+k);
  end
  @(negedge clk);valid=0;sec_end=1;
  @(negedge clk);sec_end=0;
 end
endtask
task reset_dut;
 begin
  @(negedge clk);rst=1;ack=0;valid=0;load_start=0;sec_end=0;
  repeat(3) @(negedge clk);rst=0;repeat(2) @(negedge clk);
  load_start=1;@(negedge clk);load_start=0;
 end
endtask
initial begin
 reset_dut;send_sector(0);
 if(!wr_req) $fatal(1,"Valid original 640x480 image rejected");
 ack=1;wait(!wr_req);@(negedge clk);ack=0;
 for(sector_no=0;sector_no<1801;sector_no=sector_no+1) send_sector(sector_no);
 repeat(4) @(negedge clk);
 if(emitted!=307200 || !ready || error_code!=0) $fatal(1,"Full frame not decoded");
 bad_header=1;reset_dut;send_sector(0);
 if(wr_req || !ready || error_code!=8'h31) $fatal(1,"Bad header accepted");
 bad_header=0;offset=512;length=922112;reset_dut;send_sector(0);
 if(!wr_req) $fatal(1,"Extended pixel offset rejected");
 ack=1;wait(!wr_req);@(negedge clk);ack=0;
 for(sector_no=0;sector_no<1801;sector_no=sector_no+1) send_sector(sector_no);
 repeat(4) @(negedge clk);
 if(emitted!=307200 || !ready || error_code!=0) $fatal(1,"Extended-offset frame failed");
 $display("BMP_FULL_FRAME_BGR_HEADER_OFFSET_PASS");$finish;
end
initial begin #30000000;$fatal(1,"BMP full frame timeout");end
endmodule
