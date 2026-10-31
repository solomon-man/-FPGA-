`timescale 1ns/1ps
module tb_slideshow;
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
 expect_load(4,1);
 if(db!=0 || photo!=0 || cached!=1)$fatal(1,"VGA not preserved on entry");
 repeat(65)tick;if(db!=0 || photo!=0)$fatal(1,"switch before HD EOF");
 finish_load;wait(db==4);tick;
 repeat(12)tick;if(dut.load_busy)$fatal(1,"old VGA reader not drained");
 commit;expect_load(5,2);finish_load;wait(db==5);tick;
 cb=5;cp=2;repeat(20)tick;if(dut.load_busy)$fatal(1,"old HD reader not drained");
 owned=32;expect_load(4,3);
 toggle;finish_load;
 if(db!=5 || photo!=2 || auto_on)$fatal(1,"stop lost HD5");
 expect_load(3,3);finish_load;expect_load(6,1);finish_load;
 repeat(80)tick;if(dut.load_busy || db!=5 || dut.slideshow_cache.hold_valid!=3)$fatal(1,"two-preview limit");
 nx=1;tick;nx=0;if(db!=3 || photo!=3)$fatal(1,"next preview");
 repeat(15)tick;if(dut.load_busy)$fatal(1,"restore before VGA owner");
 commit;
 for(j=0;j<3;j=j+1)begin expect_load(j,j);finish_load;end
 if(cached!=15 || db!=3 || photo!=3)$fatal(1,"manual restore");
 $display("SLIDESHOW_VGA_ENTRY_TWO_HD_DRAIN_STOP_HD5_TWO_PREVIEWS_RESTORE_PASS");
 expect_load(4,3);finish_load;wait(db==4);commit;toggle;
 expect_load(5,0);repeat(60)tick;if(db!=4)$fatal(1,"lost HD4 on entry");
 finish_load;wait(db==5);commit;
 expect_load(4,1);finish_load;wait(db==4);commit;toggle;
 expect_load(0,2);finish_load;expect_load(1,0);finish_load;
 repeat(50)tick;if(db!=4 || dut.load_busy)$fatal(1,"HD4 stop preserve");
 pv=1;tick;pv=0;if(db!=1 || photo!=0)$fatal(1,"previous transient preview");
 commit;expect_load(0,0);finish_load;
 wait(db==0);repeat(10)tick;if(dut.load_busy)$fatal(1,"home not committed");
 commit;for(j=1;j<4;j=j+1)begin expect_load(j,j);finish_load;end
 if(cached!=15 || photo!=0)$fatal(1,"transient remap restore");
 $display("SLIDESHOW_HD_ENTRY_STOP_HD4_TWO_PREVIEWS_PREV_REMAP_PASS");$finish;
end
initial begin #300000;$fatal(1,"timeout mode%0d wb%0d db%0d photo%0d busy%0d",dut.slideshow_cache.mode,wb,db,photo,dut.load_busy);end
endmodule
