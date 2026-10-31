`timescale 1ns/1ps
module tb_fat121;
reg clk=0;always #5 clk=~clk;
reg rst=1,scan=0,load=0;reg [31:0] token=0;
reg [7:0] data=0;reg valid=0,done=0;
wire req,ready,scandone,found,wen,wreq,error;
wire [31:0] lba,foundtoken;wire [23:0] pixel;wire [1:0] status;wire [7:0] err;
fat_bmp_read dut(.clk(clk),.rst(rst),.decoder_rst(rst),.ready(ready),.scan_start(scan),
 .scan_start_sector(32'd0),.scan_max_sector(32'd1900),.scan_target_count(4'd1),
 .scan_done(scandone),.scan_found_valid(found),.scan_found_sector(foundtoken),.scan_found_total(),
 .load_start(load),.load_sector(token),.sd_init_done(1'b1),.state_code(),
 .bmp_width(16'd640),.bmp_height(16'd480),.write_req(wreq),.write_req_ack(wreq),
 .sd_sec_read(req),.sd_sec_read_addr(lba),.sd_sec_read_data(data),.sd_sec_read_data_valid(valid),
 .sd_sec_read_end(done),.bmp_data_wr_en(wen),.bmp_data(pixel),.load_error(error),.bmp_error(err),.fat_status(status));
integer mode=0,partition=0,badchain=0,pixels=0,foundcount=0,requests=0;
integer fat_requests=0;
integer disk_spc=1,disk_fats=1,active_fat=0,partition_slot=0;
integer address,index,offset,cluster,entry,v,logical,px,component;
reg transport_busy=0,error_seen=0;
function [7:0] file_byte;
 input integer pos;integer p,c;
 begin
  file_byte=0;
  if(pos<54)case(pos)
   0:file_byte=66;1:file_byte=77;
   2:file_byte=921654&255;3:file_byte=(921654>>8)&255;4:file_byte=(921654>>16)&255;
   10:file_byte=54;14:file_byte=40;18:file_byte=128;19:file_byte=2;
   22:file_byte=224;23:file_byte=1;26:file_byte=1;28:file_byte=24;
  endcase
  else if(pos<921654)begin p=(pos-54)/3;c=(pos-54)%3;
   case(c)0:file_byte=p&255;1:file_byte=(p>>8)&255;2:file_byte=8'had;endcase
  end
 end
endfunction
function [7:0] disk_byte;
 input integer sector,pos;integer relative,cl,next,virt,fat_relative,data_base,cluster_sector;
 begin
  disk_byte=0;relative=sector-partition;data_base=1+520*disk_fats;
  if(mode==2)begin
   if(sector<1801)disk_byte=file_byte(sector*512+pos);
  end else if(sector==0 && partition!=0)begin
   case(pos-partition_slot*16)450:disk_byte=8'h0c;454:disk_byte=partition&255;455:disk_byte=(partition>>8)&255;
   endcase
   case(pos)
    510:disk_byte=8'h55;511:disk_byte=8'haa;endcase
  end else if(relative==0)begin
   case(pos)
    11:disk_byte=0;12:disk_byte=2;13:disk_byte=disk_spc;14:disk_byte=1;16:disk_byte=disk_fats;
    32:disk_byte=(66000*disk_spc)&255;33:disk_byte=((66000*disk_spc)>>8)&255;34:disk_byte=((66000*disk_spc)>>16)&255;
    36:disk_byte=8;37:disk_byte=2;40:disk_byte=active_fat?8'h81:0;44:disk_byte=2;
    510:disk_byte=8'h55;511:disk_byte=8'haa;
   endcase
  end else if(relative>=1 && relative<data_base)begin
   fat_relative=(relative-1)%520;cl=fat_relative*128+pos/4;next=0;
   if(cl==2)next=7;else if(cl==7)next=32'h0fffffff;
   else if(cl>=10 && cl<=10+(1800/disk_spc)*2 && cl%2==0)begin
    if(cl==10+(1800/disk_spc)*2)next=badchain==1?10:32'h0fffffff;
    else next=badchain==2 && cl==12?32'h0fffffff:cl+2;
   end
   if(active_fat && relative<=520)next=0;
   disk_byte=(next>>((pos%4)*8))&255;
  end else if(relative>=data_base && relative<data_base+disk_spc)begin
   if(pos%32==0)disk_byte=8'he5;
  end else if(relative==data_base+5*disk_spc)begin
   if(pos<32)case(pos)
    0:disk_byte="P";1:disk_byte="I";2:disk_byte="C";3:disk_byte="1";
    4,5,6,7:disk_byte=32;8:disk_byte="B";9:disk_byte="M";10:disk_byte="P";
    11:disk_byte=8'h20;26:disk_byte=10;
    28:disk_byte=921654&255;29:disk_byte=(921654>>8)&255;30:disk_byte=(921654>>16)&255;
   endcase
  end else begin
   cl=(relative-data_base)/disk_spc+2;cluster_sector=(relative-data_base)%disk_spc;
   if(cl>=10 && cl<=10+(1800/disk_spc)*2 && cl%2==0)begin
    virt=((cl-10)/2)*disk_spc+cluster_sector;disk_byte=file_byte(virt*512+pos);end
   else disk_byte=8'h77;
  end
 end
endfunction
// Held request, byte-valid gaps, and an end pulse after the last byte.
initial forever begin
 @(negedge clk);
 if(req && !rst)begin
  address=lba;requests=requests+1;transport_busy=1;
  if(mode!=2 && address>=partition+1 && address<partition+1+520*disk_fats)
   fat_requests=fat_requests+1;
  repeat(3)@(negedge clk);
  for(index=0;index<512;index=index+1)begin
   data=disk_byte(address,index);valid=1;@(negedge clk);valid=0;@(negedge clk);
  end
  repeat(2)@(negedge clk);done=1;@(negedge clk);done=0;
  repeat(3)@(negedge clk);transport_busy=0;
 end
end
always @(posedge clk)begin
 if(!rst)begin
  if(found)begin foundcount=foundcount+1;token=foundtoken;end
  if(error)error_seen=1;
  if(wen)begin
   if(pixel!=={8'had,pixels[15:8],pixels[7:0]})$fatal(1,"Fragmented BMP pixel %d got %h",pixels,pixel);
   pixels=pixels+1;
  end
 end
end
task run_case;
 input integer variant,partition_lba,broken;
 begin
  wait(!transport_busy);@(negedge clk);rst=1;scan=0;load=0;
  mode=variant;partition=partition_lba;badchain=broken;pixels=0;foundcount=0;error_seen=0;fat_requests=0;
  repeat(6)@(negedge clk);rst=0;repeat(3)@(negedge clk);
  scan=1;@(negedge clk);scan=0;wait(scandone);repeat(5)@(negedge clk);
  if(foundcount!=1 || status!=(variant==2?1:2))$fatal(1,"Mount/discovery failed count%d status%d",foundcount,status);
  load=1;@(negedge clk);load=0;wait(!ready);wait(ready);
  repeat(8)@(negedge clk);
  if(broken==0)begin
   if(error_seen || pixels!=307200)$fatal(1,"Full FAT BMP failed pixels%d err%h",pixels,err);
   if(variant!=2 && fat_requests>32)$fatal(1,"FAT cache did not reduce repeated metadata reads: %d",fat_requests);
   if(variant==0)$display("FAT32_CACHE_FULL_IMAGE_EXACT_PIXELS_METADATA_READS=%0d BASELINE_READS=1802",fat_requests);
  end else if(!error_seen)$fatal(1,"Invalid FAT chain accepted");
 end
endtask
initial begin
 // Always-ready synthetic pixel sink; real FIFO pacing is tested separately.
 force dut.decoder.pace=0;
 run_case(0,0,0);$display("FAT32_SUPERFLOPPY_FRAGMENTED_FULL_BGR_ROOT_CHAIN_PASS");
 run_case(1,2048,0);$display("FAT32_MBR_FRAGMENTED_FULL_BGR_PASS");
 disk_spc=4;disk_fats=2;active_fat=1;partition_slot=2;
 run_case(3,2048,0);$display("FAT32_MULTI_SECTOR_ACTIVE_SECOND_FAT_THIRD_MBR_PARTITION_PASS");
 disk_spc=1;disk_fats=1;active_fat=0;partition_slot=0;
 run_case(0,0,1);$display("FAT32_CIRCULAR_CHAIN_REJECTED_PASS");
 run_case(0,0,2);$display("FAT32_EARLY_EOF_REJECTED_PASS");
 run_case(2,0,0);$display("RAW_10_COMPATIBILITY_FULL_IMAGE_PASS");
 $finish;
end
initial begin #2000000000;$fatal(1,"FAT integration timeout");end
endmodule
