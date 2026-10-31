`timescale 1ns/1ps
module tb_six_fat;
reg clk=0;always #5 clk=~clk;
reg rst=1,scan=0,load=0;reg [31:0] token=0;
reg [7:0] data=0;reg valid=0,done=0;
wire req,ready,scandone,found,wen,wreq,error;
wire [31:0] lba,foundtoken;wire [23:0] pixel;wire [1:0] status;wire [7:0] err;wire [3:0] count;
fat_bmp_read #(.MAX_PHOTOS(6)) dut(.clk(clk),.rst(rst),.decoder_rst(rst),.ready(ready),.scan_start(scan),
 .scan_start_sector(32'd0),.scan_max_sector(32'd1900),.scan_target_count(4'd6),
 .scan_done(scandone),.scan_found_valid(found),.scan_found_sector(foundtoken),.scan_found_total(count),
 .load_start(load),.load_sector(token),.sd_init_done(1'b1),.state_code(),
 .bmp_width(16'd640),.bmp_height(16'd480),.write_req(wreq),.write_req_ack(wreq),
 .sd_sec_read(req),.sd_sec_read_addr(lba),.sd_sec_read_data(data),.sd_sec_read_data_valid(valid),
 .sd_sec_read_end(done),.bmp_data_wr_en(wen),.bmp_data(pixel),.load_error(error),.bmp_error(err),.fat_status(status));
integer address,b,pixels=0,seen=0,i;reg busy=0;reg [23:0] expected;
function [7:0] disk;
 input integer a,x;integer cl,nextval,entry,id;
 begin
 disk=0;
 if(a==0)case(x)
  12:disk=2;13:disk=1;14:disk=1;16:disk=1;32:disk=8'hd0;33:disk=8'hfb;
  37:disk=2;44:disk=2;510:disk=8'h55;511:disk=8'haa;
 endcase
 else if(a>=1 && a<=512)begin
  cl=(a-1)*128+x/4;nextval=0;
  if(cl==2)nextval=3;
  else if(cl==3 || (cl>=20 && cl<=40 && cl%2==0))nextval=32'h0fffffff;
  disk=nextval>>(8*(x%4));
 end else if(a==513 || a==514)begin
  entry=x/32;id=(a==513)?entry:entry+5;
  if((a==513 && entry<5) || (a==514 && entry<6))case(x%32)
   0:disk="P";1:disk=48+id;8:disk="B";9:disk="M";10:disk="P";11:disk=8'h20;
   26:disk=20+2*id;28:disk=58;
  endcase
  else if(a==513 && x%32==0)disk=8'he5;
 end else if(a>=531 && a<=551)begin
  id=(a-531)/2;
  case(x)
   0:disk="B";1:disk="M";2:disk=58;10:disk=54;14:disk=40;
   18:disk=1;22:disk=1;26:disk=1;28:disk=24;
   54:disk=id;55:disk=30+id;56:disk=80+id;
  endcase
 end
 end
endfunction
initial forever begin
 @(negedge clk);
 if(req && !rst)begin
  busy=1;address=lba;repeat(3)@(negedge clk);
  for(b=0;b<512;b=b+1)begin data=disk(address,b);valid=1;@(negedge clk);valid=0;@(negedge clk);end
  done=1;@(negedge clk);done=0;wait(!req);repeat(3)@(negedge clk);busy=0;
 end
end
always @(posedge clk)if(!rst)begin
 if(found)begin if(foundtoken!=seen)$fatal(1,"Catalog order/token");seen=seen+1;end
 if(error)$fatal(1,"BMP/FAT error %h file %d",err,token);
 if(wen)begin
  expected=(pixels%640<80 || pixels%640>=560)?24'd0:{8'(80+token),8'(30+token),8'(token)};
  if(pixel!==expected)$fatal(1,"Photo %d pixel %d wrong %h expected %h",token,pixels,pixel,expected);
  pixels=pixels+1;
 end
end
initial begin
 // This synthetic sink is always ready. Skip only the fixed SDRAM pacing wait;
 // the unchanged paced FIFO/memory path is covered by the existing suites.
 force dut.decoder.pace=0;
 repeat(5)@(negedge clk);rst=0;scan=1;@(negedge clk);scan=0;
 wait(scandone);repeat(5)@(negedge clk);
 if(seen!=6 || count!=6 || status!=2)$fatal(1,"Ten image cap across directory clusters");
 for(i=0;i<6;i=i+1)begin
  wait(!busy && ready);@(negedge clk);token=i;pixels=0;load=1;
  @(negedge clk);load=0;wait(!ready);wait(ready);repeat(8)@(negedge clk);
  if(pixels!=307200)$fatal(1,"Incomplete image %d",token);
  $display("TEN_FAT_FULL_PIXEL_FILE %0d",token+1);
 end
 $display("FAT32_SIX_BMP_DIRECTORY_CHAIN_CAP_ELEVEN_FULL_PIXELS_PASS");$finish;
end
initial begin #1000000000;$fatal(1,"Ten FAT timeout");end
endmodule
