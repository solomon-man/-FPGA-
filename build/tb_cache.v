`timescale 1ns/1ps
// Mock only sector and decoder I/O. Exercise the real cache manager across
// source/memory completion order, hot switching, failed loads and recovery.
module tb_cache;
reg clk=0;always #5 clk=~clk;
reg rst=1,finish_toggle=0;
reg [1:0] speed=1;reg reset_all_event=0;
reg next_event=0,auto_event=0,prev_event=0;
wire [1:0] write_bank,display_bank;
wire display_valid;wire [3:0] cached;wire [7:0] error_code;
sd_card_bmp #(.CLK_FREQ_HZ(1000),.LOAD_TIMEOUT_CYCLES(500),.EXTERNAL_EVENTS(1),.DYNAMIC_SPEED(1),.ENABLE_SD_AUDIO(1)) dut(
 .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.next_event(next_event),.auto_event(auto_event),.prev_event(prev_event),.music_track(3'd0),.music_play(1'b0),.music_count(),.music_status(),.music_error(),.pixel_clk(clk),.pixel_rst(rst),.audio_tick(1'b0),.audio_play_pixel(1'b0),.sd_audio_left(),.sd_audio_right(),.speed(speed),.reset_all_event(reset_all_event),.fat_status(),.state_code(),
 .bmp_width(16'd640),.bmp_height(16'd480),.display_valid(display_valid),
 .write_finish_toggle(finish_toggle),.write_buf_idx(write_bank),.disp_buf_idx(display_bank),
 .write_req(),.write_req_ack(1'b0),.write_en(),.write_data(),
 .SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),
 .auto_enabled(),.cached_mask(cached),.error_code(error_code));
task tick;begin @(negedge clk);end endtask
task load_complete;
 input integer bank;
 input integer mem_first;
 begin
  wait(dut.load_start_pulse);tick;
  if(write_bank!==bank[1:0]) $fatal(1,"Incorrect preload slot");
  force dut.bmp_ready=0;repeat(4) tick;
  if(mem_first) begin
    finish_toggle=~finish_toggle;repeat(6) tick;
    if(cached[bank]) $fatal(1,"Partial source was published");
    force dut.bmp_ready=1;
  end else begin
    force dut.bmp_ready=1;repeat(6) tick;
    if(cached[bank]) $fatal(1,"Incomplete SDRAM frame was published");
    finish_toggle=~finish_toggle;
  end
  wait(cached[bank]);tick;
 end
endtask
integer n;
initial begin
 force dut.sd_init_done=1;force dut.bmp_ready=1;
 force dut.scan_done=0;force dut.scan_found_valid=0;
 force dut.load_error=0;
 repeat(4) tick;rst=0;repeat(4) tick;
 for(n=0;n<4;n=n+1) begin
  force dut.scan_found_sector=32'd2048+n*1801;
  force dut.scan_found_valid=1;tick;
  force dut.scan_found_valid=0;tick;
 end
 force dut.scan_done=1;
 load_complete(0,1);
 if(!display_valid || display_bank!=0) $fatal(1,"First frame missing");
 load_complete(1,0);
 load_complete(2,1);
 wait(dut.load_start_pulse);tick;force dut.bmp_ready=0;
 repeat(4) tick;force dut.bmp_error=8'h37;force dut.load_error=1;tick;
 force dut.load_error=0;force dut.bmp_ready=1;
 repeat(20) tick;
 if(cached!==4'b0111 || display_bank!=0 || !display_valid || error_code!=8'h37)
    $fatal(1,"Failed load replaced good frame");
 next_event=1;tick;next_event=0;tick;
 if(display_bank!=1) $fatal(1,"Cached next image failed");
 next_event=1;tick;next_event=0;tick;
 if(display_bank!=2) $fatal(1,"Cached third image failed");
 next_event=1;tick;next_event=0;tick;
 if(display_bank!=0 || dut.load_busy) $fatal(1,"Bad slot was not skipped");
 prev_event=1;tick;prev_event=0;tick;
 if(display_bank!=2)$fatal(1,"Previous did not skip failed slot and wrap");
 prev_event=1;tick;prev_event=0;tick;
 if(display_bank!=1)$fatal(1,"Previous second cached image");
 auto_event=1;tick;auto_event=0;tick;
 if(!dut.auto_enabled)$fatal(1,"Autoplay enable");
 repeat(7998)tick;
 if(display_bank!=1)$fatal(1,"Medium advanced early");
 tick;
 if(display_bank!=2)$fatal(1,"Autoplay did not advance");
 // Changing speed restarts the whole interval.
 speed=0;tick;
 if(dut.auto_count!=0)$fatal(1,"Speed change failed to restart");
 repeat(2999)tick;if(display_bank!=2)$fatal(1,"Fast advanced early");
 tick;if(display_bank!=0)$fatal(1,"Fast must be exactly 3 seconds");
 speed=2;tick;
 repeat(14999)tick;if(display_bank!=0)$fatal(1,"Slow advanced early");
 tick;if(display_bank!=1)$fatal(1,"Slow must be exactly 15 seconds");
 reset_all_event=1;tick;reset_all_event=0;tick;
 if(dut.auto_enabled || cached!=7 || !display_valid)$fatal(1,"Reset all damaged cache or failed to stop autoplay");
 auto_event=1;tick;auto_event=0;tick;
 auto_event=1;tick;auto_event=0;tick;
 if(dut.auto_enabled)$fatal(1,"Autoplay disable");
 $display("FOUR_BANK_CACHE_COMPLETION_ERROR_SWITCH_PASS AUTOPLAY_3_8_15_SECONDS_RESET_PASS");$finish;
end
initial begin #1000000;$fatal(1,"Cache manager timeout");end
endmodule
