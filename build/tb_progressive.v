`timescale 1ns/1ps
module tb_progressive;
reg clk=0;always #5 clk=~clk;
reg rst=1,ft=0,next_ev=0,prev_ev=0,hd_busy=0;
reg [2:0] committed=0;reg [3:0] cp=0;reg cv=0;
wire [2:0] wb,db;wire [3:0] cached,photo;wire valid;
sd_card_bmp #(.PROGRESSIVE(1),.BANK_BITS(3),.CACHE_SLOTS(4),.MAX_PHOTOS(4),.WAIT_COMMIT(1),
 .EXTERNAL_EVENTS(1),.DYNAMIC_SPEED(1),.CLK_FREQ_HZ(1000),.LOAD_TIMEOUT_CYCLES(500)) dut(
 .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.hd_read_busy(hd_busy),
 .next_event(next_ev),.prev_event(prev_ev),.auto_event(1'b0),.speed(2'd0),.reset_all_event(1'b0),
 .bmp_width(16'd640),.bmp_height(16'd480),.display_valid(valid),.write_finish_toggle(ft),
 .write_buf_idx(wb),.disp_buf_idx(db),.write_req(),.write_req_ack(1'b0),.write_en(),.write_data(),
 .SD_MISO(1'b1),.cached_mask(cached),.music_track(3'd0),.music_play(1'b0),
 .pixel_clk(clk),.pixel_rst(rst),.audio_tick(1'b0),.audio_play_pixel(1'b0),
 .committed_bank(committed),.committed_photo(cp),.committed_valid(cv),.photo_index(photo));
task tick;begin @(negedge clk);end endtask
task complete;input integer b;begin
 wait(dut.load_start_pulse);tick;
 if(wb!=b)$fatal(1,"wrong loading bank got %d expected %d",wb,b); //");
 force dut.bmp_ready=0;repeat(8)tick;
 ft=~ft;repeat(8)tick;
 if(b==4 && db==4)$fatal(1,"early HD publication");
 force dut.bmp_ready=1;tick;
end endtask
integer n;
initial begin
 force dut.sd_init_done=1;force dut.bmp_ready=1;force dut.load_error=0;
 force dut.scan_done=0;force dut.scan_found_valid=0;force dut.fat_status=2;
 repeat(4)tick;rst=0;repeat(4)tick;
 for(n=0;n<4;n=n+1)begin force dut.scan_found_sector=n;force dut.scan_found_valid=1;tick;force dut.scan_found_valid=0;tick;end
 force dut.scan_done=1;
 for(n=0;n<4;n=n+1)complete(n);
 if(cached!=15 || !valid)$fatal(1,"preview preload");
 committed=0;cp=0;cv=1;
 complete(4);
 if(db!=4 || photo!=0)$fatal(1,"HD promotion");
 committed=4;hd_busy=1;repeat(5)tick;
 next_ev=1;tick;next_ev=0;
 if(db!=1 || photo!=1)$fatal(1,"preview navigation");
 repeat(12)tick;
 if(dut.load_busy)$fatal(1,"overwrote displayed HD");
 committed=1;cp=1;repeat(12)tick;
 if(dut.load_busy)$fatal(1,"overwrote outstanding memory read");
 hd_busy=0;wait(dut.load_start_pulse);tick;force dut.bmp_ready=0;
 next_ev=1;tick;next_ev=0;
 if(photo!=2 || db!=2)$fatal(1,"navigation blocked by HD load");
 ft=~ft;repeat(8)tick;force dut.bmp_ready=1;repeat(4)tick;
 if(db==4)$fatal(1,"stale HD published");
 committed=2;cp=2;wait(dut.load_start_pulse);tick;force dut.bmp_ready=0;
 force dut.load_error=1;tick;force dut.load_error=0;force dut.bmp_ready=1;repeat(30)tick;
 if(db!=2 || dut.load_busy)$fatal(1,"HD error did not retain preview");
 $display("PROGRESSIVE_PREVIEW_HD_OWNERSHIP_DRAIN_STALE_FAILURE_PASS");$finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
