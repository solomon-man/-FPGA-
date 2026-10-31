`timescale 1ns/1ps
module tb_six_cache;
reg clk=0;always #5 clk=~clk;
reg rst=1,finish_toggle=0,ne=0,pe=0,ae=0;
reg [2:0] committed_bank=0;reg [3:0] committed_photo=0;reg committed_valid=0;
wire [2:0] wb,db;wire [3:0] photo;wire valid;wire [5:0] cached;
integer contents[0:5];integer loads=0,i,fail_photo=-1,catalog_count=10;
sd_card_bmp #(.CLK_FREQ_HZ(100),.EXTERNAL_EVENTS(1),.DYNAMIC_SPEED(1),
 .BANK_BITS(3),.CACHE_SLOTS(6),.MAX_PHOTOS(6),.WAIT_COMMIT(1),
 .SCAN_TARGET_COUNT(6),.LOAD_TIMEOUT_CYCLES(500)) dut(
 .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.next_event(ne),.prev_event(pe),.auto_event(ae),
 .speed(2'd0),.reset_all_event(1'b0),.fat_status(),.state_code(),.bmp_width(16'd640),.bmp_height(16'd480),
 .display_valid(valid),.write_finish_toggle(finish_toggle),.write_buf_idx(wb),.disp_buf_idx(db),
 .write_req(),.write_req_ack(1'b0),.write_en(),.write_data(),.SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),
 .auto_enabled(),.cached_mask(cached),.error_code(),.music_track(3'd0),.music_play(1'b0),
 .pixel_clk(clk),.pixel_rst(rst),.audio_tick(1'b0),.audio_play_pixel(1'b0),
 .committed_bank(committed_bank),.committed_photo(committed_photo),.committed_valid(committed_valid),.photo_index(photo));
task tick;begin @(negedge clk);end endtask
always @(negedge clk)if(!rst)begin
 committed_bank=db;committed_photo=photo;committed_valid=valid;
 if(valid && contents[db]!=photo)$fatal(1,"Cached image identity mismatch");
end
initial begin
 force dut.bmp_ready=1;force dut.load_error=0;force dut.bmp_error=8'h37;
 forever begin
  wait(dut.load_start_pulse);tick;
  if(valid && wb==db)$fatal(1,"Overwriting displayed image");
  if(dut.load_sector!==32'd1000+wb)$fatal(1,"Catalog token mismatch");
  loads=loads+1;force dut.bmp_ready=0;repeat(5)tick;
  if(wb==fail_photo)begin force dut.load_error=1;tick;force dut.load_error=0;force dut.bmp_ready=1;end
  else begin
   contents[wb]=wb;
   if(loads%2)begin finish_toggle=~finish_toggle;repeat(6)tick;force dut.bmp_ready=1;end
   else begin force dut.bmp_ready=1;repeat(6)tick;finish_toggle=~finish_toggle;end
  end
  wait(!dut.load_busy);tick;
 end
end
task boot;
 input integer entries;
 begin
  rst=1;force dut.scan_done=0;force dut.scan_found_valid=0;committed_valid=0;loads=0;
  for(i=0;i<6;i=i+1)contents[i]=-1;
  repeat(5)tick;rst=0;repeat(5)tick;
  for(i=0;i<entries;i=i+1)begin
   force dut.scan_found_sector=32'd1000+i;force dut.scan_found_valid=1;tick;force dut.scan_found_valid=0;tick;
  end
  force dut.scan_done=1;wait(!dut.preload_found && !dut.load_busy);repeat(20)tick;
 end
endtask
task nav;
 input integer backwards,expected;
 begin
  pe=backwards;ne=!backwards;tick;pe=0;ne=0;repeat(8)tick;
  if(photo!=expected)$fatal(1,"Navigation expected=%d got=%d",expected,photo);
 end
endtask
initial begin
 force dut.sd_init_done=1;boot(10);
 if(dut.found_count!=6 || cached!=63 || loads!=6)$fatal(1,"Six resident cap/preload failed");
 repeat(3)begin
  for(i=1;i<6;i=i+1)nav(0,i);nav(0,0);nav(1,5);
  for(i=4;i>=0;i=i-1)nav(1,i);
 end
 if(loads!=6)$fatal(1,"Cached navigation reloaded SD");
 ae=1;tick;ae=0;wait(photo==1);ae=1;tick;ae=0;
 if(loads!=6)$fatal(1,"Autoplay reloaded SD");
 fail_photo=1;boot(6);nav(0,2);nav(1,0);
 if(loads!=6 || cached!=61)$fatal(1,"Failed photo handling");
 fail_photo=-1;boot(3);nav(1,2);nav(0,0);
 if(loads!=3 || cached!=7)$fatal(1,"Short catalog wrap");
 $display("SIX_RESIDENT_CAP_NO_RELOAD_FORWARD_REVERSE_WRAP_AUTOPLAY_FAILURE_SHORT_CATALOG_PASS");$finish;
end
initial begin #2000000;$fatal(1,"Six resident timeout");end
endmodule
