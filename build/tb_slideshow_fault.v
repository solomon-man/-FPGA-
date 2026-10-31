`timescale 1ns/1ps
module tb_slideshow_fault;
reg clk=0;always #5 clk=~clk;
reg rst=1,ft=0,nx=0,pv=0,au=0;
reg [2:0] cb=0;reg [3:0] cp=0;reg cv=0;reg [6:0] owned=0;
wire [2:0] wb,db;wire [3:0] cached,photo;wire valid,auto_on;
sd_card_bmp #(.PROGRESSIVE(1),.SLIDESHOW_HD(1),.BANK_BITS(3),.CACHE_SLOTS(4),.MAX_PHOTOS(4),.WAIT_COMMIT(1),
 .EXTERNAL_EVENTS(1),.DYNAMIC_SPEED(1),.CLK_FREQ_HZ(10),.LOAD_TIMEOUT_CYCLES(500)) dut(
 .clk(clk),.rst(rst),.reader_owned(owned),.key_next(1'b1),.key_auto(1'b1),.hd_read_busy(1'b0),
 .next_event(nx),.prev_event(pv),.auto_event(au),.speed(2'd0),.reset_all_event(1'b0),
 .bmp_width(16'd640),.bmp_height(16'd480),.display_valid(valid),.write_finish_toggle(ft),
 .write_buf_idx(wb),.disp_buf_idx(db),.write_req(),.write_req_ack(1'b0),.write_en(),.write_data(),
 .SD_MISO(1'b1),.cached_mask(cached),.auto_enabled(auto_on),.music_track(3'd0),.music_play(1'b0),
 .pixel_clk(clk),.pixel_rst(rst),.audio_tick(1'b0),.audio_play_pixel(1'b0),
 .committed_bank(cb),.committed_photo(cp),.committed_valid(cv),.photo_index(photo));
task tick;begin @(negedge clk);end endtask
task toggle;begin au=1;tick;au=0;end endtask
task commit;begin cb=db;cp=photo;cv=1;repeat(3)tick;owned=7'b1<<db;end endtask
task expect_load;input integer b,p;begin
 wait(dut.load_start_pulse);tick;
 if(wb!=b || dut.slideshow_cache.loading_photo!=p)$fatal(1,"load got %0d/%0d expected %0d/%0d",wb,dut.slideshow_cache.loading_photo,b,p);
 force dut.bmp_ready=0;
end endtask
task finish_load;begin
 repeat(4)tick;ft=~ft;repeat(5)tick;force dut.bmp_ready=1;repeat(2)tick;
end endtask
integer j;
initial begin
 force dut.sd_init_done=1;force dut.bmp_ready=1;force dut.load_error=0;
 force dut.scan_done=0;force dut.scan_found_valid=0;force dut.fat_status=2;
 repeat(4)tick;rst=0;repeat(4)tick;
 for(j=0;j<4;j=j+1)begin force dut.scan_found_sector=j;force dut.scan_found_valid=1;tick;force dut.scan_found_valid=0;tick;end
 force dut.scan_done=1;
 for(j=0;j<4;j=j+1)begin expect_load(j,j);finish_load;end
 if(cached!=15 || db!=0)$fatal(1,"startup previews");
 cb=0;cp=0;cv=1;toggle;owned=1;
 expect_load(4,1);force dut.load_error=1;tick;force dut.load_error=0;force dut.bmp_ready=1;
 repeat(4)tick;if(db!=0 || photo!=0)$fatal(1,"failed HD replaced VGA");
 expect_load(4,2);finish_load;wait(db==4);commit;
 expect_load(5,3);repeat(501)tick;force dut.bmp_ready=1;
 if(db!=4 || photo!=2)$fatal(1,"timeout replaced current HD");
 toggle;
 // Drain the recovery; stop retains current HD despite failure of the prefetched file.
 expect_load(0,3);finish_load;
 expect_load(1,1);
 // A navigation press made while its preview is still loading must be remembered.
 pv=1;tick;pv=0;if(db!=4)$fatal(1,"incomplete preview published");
 finish_load;wait(db==1);tick;
 if(photo!=1)$fatal(1,"queued previous was lost");
 commit;
 // Bank 1 already matches photo 1; remaining previews are loaded after the switch.
 expect_load(0,0);finish_load;expect_load(2,2);finish_load;expect_load(3,3);finish_load;
 if(cached!=15 || photo!=1)$fatal(1,"restore after timeout");
 $display("SLIDESHOW_HD_ERROR_TIMEOUT_PRESERVE_QUEUED_NAV_RESTORE_PASS");$finish;
end
initial begin #300000;$fatal(1,"fault test timeout mode%0d wb%0d db%0d photo%0d busy%0d",dut.slideshow_cache.mode,wb,db,photo,dut.load_busy);end
endmodule
