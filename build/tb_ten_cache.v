`timescale 1ns/1ps
module tb_ten_cache;
reg clk=0;always #5 clk=~clk;
reg rst=1,finish_toggle=0,ne=0,pe=0,ae=0;
reg [1:0] committed_bank=0;reg [3:0] committed_photo=0;reg committed_valid=0;
wire [1:0] wb,db;wire [3:0] photo;wire valid;wire [3:0] cached;
integer contents[0:3];integer loads=0,delay_commit=0,i,fail_photo=-1;
reg fail_first_four=0;
sd_card_bmp #(.CLK_FREQ_HZ(100),.EXTERNAL_EVENTS(1),.DYNAMIC_SPEED(1),.DYNAMIC_CATALOG(1),
 .SCAN_TARGET_COUNT(10),.LOAD_TIMEOUT_CYCLES(500)) dut(
 .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.next_event(ne),.prev_event(pe),.auto_event(ae),
 .speed(2'd0),.reset_all_event(1'b0),.fat_status(),.state_code(),.bmp_width(16'd640),.bmp_height(16'd480),
 .display_valid(valid),.write_finish_toggle(finish_toggle),.write_buf_idx(wb),.disp_buf_idx(db),
 .write_req(),.write_req_ack(1'b0),.write_en(),.write_data(),.SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),
 .auto_enabled(),.cached_mask(cached),.error_code(),.music_track(3'd0),.music_play(1'b0),
 .pixel_clk(clk),.pixel_rst(rst),.audio_tick(1'b0),.audio_play_pixel(1'b0),
 .committed_bank(committed_bank),.committed_photo(committed_photo),.committed_valid(committed_valid),.photo_index(photo));
task tick;begin @(negedge clk);end endtask
always @(negedge clk)if(!rst)begin
 if(valid && (!committed_valid || committed_photo!=photo))begin
  if(delay_commit==40)begin committed_bank=db;committed_photo=photo;committed_valid=1;delay_commit=0;end
  else delay_commit=delay_commit+1;
 end
 if(valid && contents[db]!=photo)$fatal(1,"Photo identity does not match cached image");
end
initial begin
 force dut.bmp_ready=1;force dut.load_error=0;force dut.bmp_error=8'h37;
 forever begin
  wait(dut.load_start_pulse);tick;
  if(committed_valid && wb==committed_bank)$fatal(1,"Overwriting frame still on screen");
  if(valid && wb==db)$fatal(1,"Overwriting requested frame");
  if(dut.load_sector!==32'd1000+dut.ten_photo_cache.loading_photo)$fatal(1,"Wrong catalog token");
  loads=loads+1;force dut.bmp_ready=0;repeat(5)tick;
  if(dut.ten_photo_cache.loading_photo==fail_photo || (fail_first_four && dut.ten_photo_cache.loading_photo<4))begin
   force dut.load_error=1;tick;force dut.load_error=0;force dut.bmp_ready=1;
  end else begin
   contents[wb]=dut.ten_photo_cache.loading_photo;
   if(loads%2)begin finish_toggle=~finish_toggle;repeat(6)tick;force dut.bmp_ready=1;end
   else begin force dut.bmp_ready=1;repeat(6)tick;finish_toggle=~finish_toggle;end
  end
  wait(!dut.load_busy);tick;
 end
end
task navigate;
 input integer backwards,expected;
 begin
  wait(!dut.load_busy && !dut.preload_found && !dut.ten_photo_cache.demand_pending && committed_photo==photo);
  repeat(3)tick;pe=backwards;ne=!backwards;tick;pe=0;ne=0;
  wait(photo==expected);wait(committed_photo==photo);repeat(3)tick;
 end
endtask
initial begin
 for(i=0;i<4;i=i+1)contents[i]=-1;
 force dut.sd_init_done=1;force dut.scan_done=0;force dut.scan_found_valid=0;
 repeat(5)tick;rst=0;repeat(5)tick;
 for(i=0;i<11;i=i+1)begin
  force dut.scan_found_sector=32'd1000+i;force dut.scan_found_valid=1;tick;force dut.scan_found_valid=0;tick;
 end
 force dut.scan_done=1;
 wait(cached==15);wait(!dut.load_busy);wait(committed_valid);
 if(dut.found_count!=10 || photo!=0 || loads!=4)$fatal(1,"Ten-photo cap or initial preload failed");
 for(i=1;i<10;i=i+1)navigate(0,i);
 navigate(0,0);navigate(1,9);
 for(i=8;i>=0;i=i-1)navigate(1,i);
 if(loads<=10)$fatal(1,"Evicted pictures were not reloaded");
 // Photo 6 has been evicted; a failed reload must leave photo 5 intact.
 for(i=1;i<5;i=i+1)navigate(0,i);
 fail_photo=5;
 ne=1;tick;ne=0;wait(dut.ten_photo_cache.failed_photos[5]);repeat(30)tick;
 if(photo!=4 || !valid || committed_photo!=4)$fatal(1,"Failed image replaced current picture");
 navigate(0,6);navigate(1,4);
 ae=1;tick;ae=0;
 wait(photo==6);wait(committed_photo==6);
 ae=1;tick;ae=0;
 // A corrupt initial group must not hide valid later catalog entries.
 tick;rst=1;force dut.scan_done=0;committed_valid=0;committed_photo=0;committed_bank=0;delay_commit=0;
 fail_photo=-1;fail_first_four=1;loads=0;
 for(i=0;i<4;i=i+1)contents[i]=-1;
 repeat(5)tick;rst=0;repeat(5)tick;
 for(i=0;i<10;i=i+1)begin
  force dut.scan_found_sector=32'd1000+i;force dut.scan_found_valid=1;tick;force dut.scan_found_valid=0;tick;
 end
 force dut.scan_done=1;
 wait(valid && photo==4);wait(committed_photo==4);
 if(loads!=5)$fatal(1,"Did not find first valid photo beyond four failed files");
 navigate(1,9);navigate(0,4);
 $display("TEN_PHOTO_CAP_FORWARD_REVERSE_WRAP_EVICTION_RELOAD_ACTIVE_PROTECTION_ERROR_AUTOPLAY_PASS");$finish;
end
initial begin #2000000;$fatal(1,"Ten photo cache timeout photo=%d loads=%d",photo,loads);end
endmodule
