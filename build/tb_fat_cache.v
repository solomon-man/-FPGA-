`timescale 1ns/1ps
module tb_fat_cache;
reg clk=0;always #5 clk=~clk;
reg rst=1,mount=0,load=0,vreq=0;
reg [31:0] vlba=0;
wire mounted,req,vvalid,vend,err;
wire [31:0] lba;wire [7:0] vdata,code;wire [1:0] status;
reg [7:0] data=0;reg valid=0,done=0,busy=0;
integer reads=0,fat_reads=0,idx,address,entry,value,n,bytes_seen;
integer baseline_reads,baseline_fat;time started,baseline_time,cached_time;
fat32_sector_map dut(.clk(clk),.rst(rst),.abort_load(1'b0),.sd_ready(1'b1),
 .mount_start(mount),.mount_done(mounted),.found_valid(),.found_token(),.found_count(),.fat_status(status),
 .load_start(load),.file_index(4'd0),.virtual_req(vreq),.virtual_lba(vlba),
 .virtual_data(vdata),.virtual_valid(vvalid),.virtual_end(vend),.load_error(err),.fs_error(code),
 .sector_req(req),.sector_lba(lba),.sector_data(data),.sector_valid(valid),.sector_done(done));
function [7:0] disk;
 input integer a,b;integer cl,nextval;
 begin
 disk=0;
 if(a==0)case(b)
  12:disk=2;13:disk=1;14:disk=1;16:disk=1;
  32:disk=8'hd0;33:disk=8'hfb; // 64464 sectors, with 512 FAT sectors.
  37:disk=2;44:disk=2;510:disk=8'h55;511:disk=8'haa;
 endcase
 else if(a>=1 && a<=512)begin
  cl=(a-1)*128+b/4;nextval=0;
  if(cl==2 || cl==132)nextval=32'h0fffffff;
  else if(cl>=4 && cl<132)nextval=cl+1;
  disk=nextval>>(8*(b%4));
 end else if(a==513)case(b)
  0:disk="P";8:disk="B";9:disk="M";10:disk="P";11:disk=8'h20;26:disk=4;
  29:disk=2;30:disk=1; // 129 * 512 bytes.
 endcase
 else begin
  disk=(a+b)&255;
  if(a==515)case(b)2:disk=0;3:disk=2;4:disk=1;5:disk=0;endcase
 end
 end
endfunction
initial forever begin
 @(negedge clk);
 if(req && !rst)begin
  busy=1;address=lba;reads=reads+1;
  if(address>=1 && address<=512)fat_reads=fat_reads+1;
  repeat(3)@(negedge clk);
  for(idx=0;idx<512;idx=idx+1)begin
   data=disk(address,idx);valid=1;@(negedge clk);valid=0;@(negedge clk);
  end
  done=1;@(negedge clk);done=0;wait(!req);repeat(2)@(negedge clk);busy=0;
 end
end
always @(posedge clk)if(!rst)begin
 if(err)$fatal(1,"FAT cache error %h sector %d count=%d index=%b size=%h sectors=%h table0=%h",code,vlba,dut.found_count,dut.file_index,dut.file_size,dut.file_sectors,dut.sizes[0]);
 if(vvalid)begin
  if(vdata!==disk(515+vlba,bytes_seen))$fatal(1,"Virtual byte mismatch");
  bytes_seen=bytes_seen+1;
 end
end
task run_file;begin
 wait(!busy);rst=1;mount=0;vreq=0;load=0;reads=0;fat_reads=0;
 repeat(5)@(negedge clk);rst=0;started=$time;
 mount=1;@(negedge clk);mount=0;wait(mounted);
 if(status!=2)$fatal(1,"Mount failed");
 repeat(4)@(negedge clk);load=1;@(negedge clk);load=0;
 for(n=0;n<129;n=n+1)begin
  wait(dut.state==dut.READY);@(negedge clk);bytes_seen=0;vlba=n;vreq=1;
  wait(vend);@(negedge clk);vreq=0;
  if(bytes_seen!=512)$fatal(1,"Sector byte count %d",bytes_seen);
  wait(dut.state==dut.READY);
 end
end endtask
initial begin
 force dut.fat_cache_valid=0;
 run_file;baseline_reads=reads;baseline_fat=fat_reads;baseline_time=$time-started;
 release dut.fat_cache_valid;
 run_file;cached_time=$time-started;
 if(baseline_fat!=129 || fat_reads!=2 || cached_time>=baseline_time)
  $fatal(1,"Cache benefit missing baseline=%d cached=%d",baseline_fat,fat_reads);
 $display("FAT_CACHE_IDENTICAL_BYTES_CROSS_SECTOR_EOF_PASS FAT_READS=%0d->%0d TOTAL_READS=%0d->%0d TIME_NS=%0t->%0t",
  baseline_fat,fat_reads,baseline_reads,reads,baseline_time,cached_time);
 $finish;
end
initial begin #20000000;$fatal(1,"Cache benchmark timeout");end
endmodule
