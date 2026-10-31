// project1.2: original SD transport, one immutable SDRAM slot per image.
module sd_card_bmp #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter [31:0] SCAN_START_SECTOR = 0,
    parameter [31:0] SCAN_MAX_SECTOR = 131071,
    parameter [3:0] SCAN_TARGET_COUNT = 4,
    parameter integer DYNAMIC_CATALOG = 0,
    parameter integer BANK_BITS=2, CACHE_SLOTS=4, MAX_PHOTOS=10,
    parameter integer WAIT_COMMIT=0, PROGRESSIVE=0, SLIDESHOW_HD=0,
    parameter integer AUTO_SECONDS = 1,
    parameter integer EXTERNAL_EVENTS = 0,
    parameter integer DYNAMIC_SPEED = 0,
    parameter integer ENABLE_SD_AUDIO = 0,
    parameter integer ENABLE_SD_WAV = 0,
    parameter [33:0] LOAD_TIMEOUT_CYCLES = 34'd6_000_000_000
)(
    input [6:0] reader_owned,
    input clk, rst, key_next, key_auto,input hd_read_busy,input next_event,auto_event,prev_event,
    input [1:0] speed,input reset_all_event,
    output [1:0] fat_status,
    output [3:0] state_code,
    input [15:0] bmp_width, bmp_height,
    output reg display_valid,
    input write_finish_toggle,
    output reg [BANK_BITS-1:0] write_buf_idx, disp_buf_idx,
    output write_req, input write_req_ack,
    output write_en, output [31:0] write_data,
    output SD_nCS, SD_DCLK, SD_MOSI, input SD_MISO,
    output reg auto_enabled, output reg [CACHE_SLOTS-1:0] cached_mask,
    output reg [7:0] error_code,
    input [2:0] music_track,input music_play,
    output [2:0] music_count,music_status,output [7:0] music_error,
    input pixel_clk,pixel_rst,audio_tick,audio_play_pixel,
    output [23:0] sd_audio_left,sd_audio_right,
    input [BANK_BITS-1:0] committed_bank,input [3:0] committed_photo,input committed_valid,
    output reg [3:0] photo_index
);
wire key_next_press, key_auto_press;
generate if(EXTERNAL_EVENTS) begin
 assign key_next_press=next_event;assign key_auto_press=auto_event;
end else begin
 key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) kn(clk,rst,key_next,key_next_press);
 key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) ka(clk,rst,key_auto,key_auto_press);
end endgenerate
wire audio_bus_timeout;
wire sd_init_done, bmp_ready, scan_done, scan_found_valid;
wire [31:0] scan_found_sector;
wire [3:0] scan_found_total;
wire sd_sec_read, sd_sec_read_data_valid, sd_sec_read_end;
wire [31:0] sd_sec_read_addr;
wire [7:0] sd_sec_read_data;
wire bmp_data_wr_en;
wire [23:0] bmp_data;
wire load_error;
wire [7:0] bmp_error;
reg scan_start_pulse, load_start_pulse, scan_kicked, load_busy;
reg [31:0] load_sector;
reg [31:0] sectors [0:9];
reg [3:0] found_count;
// found_count guards every directory token read; unused RAM need not reset.
// found_count is cleared by rst, so entries are rewritten before any read.
always @(posedge clk)
 if(scan_found_valid && found_count<(DYNAMIC_CATALOG?MAX_PHOTOS:CACHE_SLOTS))
  sectors[found_count]<=scan_found_sector;
reg [CACHE_SLOTS-1:0] attempted_mask;
reg [2:0] finish_sync;
reg source_seen, finish_seen, directory_done;
reg [31:0] auto_count;
reg [33:0] load_count;
reg [3:0] recover_count;
wire engine_rst = rst || (recover_count != 0);
wire finish_pulse = finish_sync[2] ^ finish_sync[1];
reg [1:0] speed_q;
wire speed_changed = DYNAMIC_SPEED && speed!=speed_q;
wire reset_playback = DYNAMIC_SPEED && reset_all_event;
wire [31:0] auto_limit = !DYNAMIC_SPEED ? CLK_FREQ_HZ * AUTO_SECONDS - 1 :
 speed==0 ? CLK_FREQ_HZ*3-1 : speed==2 ? CLK_FREQ_HZ*15-1 : CLK_FREQ_HZ*8-1;
assign write_en = bmp_data_wr_en;
assign write_data = {bmp_data,8'b0};
integer j;
reg [BANK_BITS-1:0] preload_index, next_index,previous_index;
integer forward_slot,reverse_slot;
wire fixed_settled=!WAIT_COMMIT || (committed_valid && committed_bank==disp_buf_idx && committed_photo==photo_index);
reg preload_found, next_found,previous_found;
always @* begin
    preload_found = 0;
    preload_index = 0;
    for (integer n=CACHE_SLOTS-1; n>=0; n=n-1) begin
        if (n < found_count && !attempted_mask[n]) begin
            preload_found = 1;
            preload_index = n;
        end
    end
    next_found = 0;
    next_index = disp_buf_idx;
    previous_found=0;previous_index=disp_buf_idx;
    for (integer n=CACHE_SLOTS; n>=1; n=n-1) begin
        forward_slot=(PROGRESSIVE?photo_index:disp_buf_idx)+n;
        if(forward_slot>=CACHE_SLOTS)forward_slot=forward_slot-CACHE_SLOTS;
        reverse_slot=(PROGRESSIVE?photo_index:disp_buf_idx)+CACHE_SLOTS-n;
        if(reverse_slot>=CACHE_SLOTS)reverse_slot=reverse_slot-CACHE_SLOTS;
        if (cached_mask[forward_slot]) begin
            next_found = 1;
            next_index = forward_slot;
        end
        if(cached_mask[reverse_slot])begin
            previous_found=1;previous_index=reverse_slot;
        end
    end
end
generate if(PROGRESSIVE && SLIDESHOW_HD)begin: slideshow_cache
// Dual-HD slideshow controller. Bank 4: 1228800..2015231; bank 5: 0..786431.
// Bank 6 aliases bank 4's first VGA frame, ONLY while bank 4 is not displayed.
// reader_owned is a conservative synchronized one-hot ownership acknowledgement.
localparam M_MANUAL=0,M_AUTO=1,M_HOLD=2,M_RESTORE=3;
localparam L_PREVIEW=0,L_MANUAL_HD=1,L_AUTO_HD=2,L_HOLD=3,L_HOME=4;
reg [1:0] mode;
reg [2:0] load_kind;
reg [3:0] loading_photo,candidate;
reg [3:0] hd_failed;
reg hd_ready;
reg [2:0] ready_bank;
reg [3:0] ready_photo;
reg [1:0] hold_valid,hold_attempted;
reg hold_loading;
reg [3:0] hold_photo0,hold_photo1;
reg [2:0] hold_bank0,hold_bank1;
reg restore_published;
reg [1:0] hold_nav;
wire current_hd=(disp_buf_idx==4 || disp_buf_idx==5);
// Registered commit match. Every cycle that moves the displayed bank or photo
// clears it, so a match against the previous selection is never reused.
reg commit_match,display_moved;
wire settled=!WAIT_COMMIT || commit_match;
// Registered ownership lookup (3.0 timing). A bank move clears commit_match on
// the same edge, so the one-cycle-stale owner_q is always masked by settled.
reg owner_q;
always @(posedge clk or posedge rst)
 if(rst) owner_q<=0;
 else owner_q<=reader_owned[disp_buf_idx];
wire owner_here=(WAIT_COMMIT?owner_q:reader_owned[disp_buf_idx]) && settled;
wire [3:0] following=(photo_index+1>=found_count)?4'd0:photo_index+1'b1;
wire [3:0] preceding=photo_index==0?found_count-1'b1:photo_index-1'b1;
// Break the timer comparison -> navigation -> cache scheduler path.
// The zero guard discards a pending result immediately after a timer reset.
reg interval_elapsed;
always @(posedge clk or posedge rst)
 if(rst) interval_elapsed<=0;
 else interval_elapsed<=auto_count>=auto_limit;
wire auto_due=interval_elapsed && (auto_count!=0) && !key_auto_press && !speed_changed && !reset_playback;
wire auto_switch=mode==M_AUTO && auto_enabled && settled && hd_ready &&
 (auto_due || key_next_press) && !key_auto_press && !reset_playback && !prev_event;
wire manual_prev=mode==M_MANUAL && !auto_enabled && display_valid && settled && previous_found && prev_event;
wire manual_next=mode==M_MANUAL && !auto_enabled && display_valid && settled && next_found && key_next_press;
wire stop_auto=reset_playback || prev_event || (key_auto_press && auto_enabled);
reg [2:0] hold_choice;
reg hold_hit;
// Neighbour matches settle long before hold_valid is set; photo_index and
// hold_photo* do not change while in M_HOLD until a hold hit leaves it.
reg hold0_next,hold0_prev,hold1_next,hold1_prev;
always @(posedge clk or posedge rst)
 if(rst)begin hold0_next<=0;hold0_prev<=0;hold1_next<=0;hold1_prev<=0;end
 else begin
  hold0_next<=hold_photo0==following;hold0_prev<=hold_photo0==preceding;
  hold1_next<=hold_photo1==following;hold1_prev<=hold_photo1==preceding;
 end
always @* begin
 hold_hit=0;hold_choice=0;
 if(hold_valid[0] && (((key_next_press || hold_nav==1) && hold0_next) || ((prev_event || hold_nav==2) && hold0_prev)))begin
  hold_hit=1;hold_choice=hold_bank0;
 end
 if(hold_valid[1] && (((key_next_press || hold_nav==1) && hold1_next) || ((prev_event || hold_nav==2) && hold1_prev)))begin
  hold_hit=1;hold_choice=hold_bank1;
 end
end
always @(posedge clk or posedge rst)begin
 if(rst)begin
  scan_start_pulse<=0;load_start_pulse<=0;scan_kicked<=0;load_sector<=0;load_busy<=0;
  found_count<=0;cached_mask<=0;attempted_mask<=0;display_valid<=0;disp_buf_idx<=0;
  write_buf_idx<=0;photo_index<=0;loading_photo<=0;hd_failed<=0;
  auto_enabled<=0;auto_count<=0;speed_q<=1;load_count<=0;finish_sync<=0;
  source_seen<=0;finish_seen<=0;error_code<=0;recover_count<=0;directory_done<=0;
  mode<=M_MANUAL;load_kind<=L_PREVIEW;candidate<=0;hd_ready<=0;ready_bank<=4;ready_photo<=0;
  hold_valid<=0;hold_attempted<=0;hold_loading<=0;hold_photo0<=0;hold_photo1<=0;
  hold_bank0<=0;hold_bank1<=1;restore_published<=0;hold_nav<=0;
  commit_match<=0;display_moved=0;
 end else begin
  display_moved=0;
  // Counter clears whenever idle, so load starts need no clear (3.0 timing).
  load_count<=load_busy?load_count+1'b1:34'd0;
  speed_q<=speed;finish_sync<={finish_sync[1:0],write_finish_toggle};
  scan_start_pulse<=0;load_start_pulse<=0;
  if(recover_count!=0)recover_count<=recover_count-1'b1;
  if(!scan_kicked && sd_init_done && bmp_ready && !engine_rst)begin scan_start_pulse<=1;scan_kicked<=1;end
  if(scan_done)directory_done<=1;
  if(scan_found_valid && found_count<4)found_count<=found_count+1'b1;
  if(fat_status==3)error_code<=8'h52;
  if(mode==M_HOLD)begin
   if(prev_event)hold_nav<=2;else if(key_next_press)hold_nav<=1;
  end
  if(reset_playback)begin auto_enabled<=0;auto_count<=0;end
  else if(mode==M_AUTO && prev_event)begin auto_enabled<=0;auto_count<=0;end
  else if(key_auto_press && display_valid)begin auto_enabled<=~auto_enabled;auto_count<=0;end
  else if(speed_changed)auto_count<=0;
  else if(auto_enabled && display_valid && settled)begin
   if(auto_count<auto_limit)auto_count<=auto_count+1'b1;
  end

  if(audio_bus_timeout)begin
   recover_count<=8;load_busy<=0;error_code<=8'h41;
   if(load_kind==L_MANUAL_HD || load_kind==L_AUTO_HD)hd_failed[loading_photo]<=1;
  end else if(load_busy)begin
   if(bmp_ready && !load_start_pulse)source_seen<=1;
   if(finish_pulse)finish_seen<=1;
   // load_count advances at the top of this block while load_busy.
   if((source_seen || (bmp_ready && !load_start_pulse)) && (finish_seen || finish_pulse) && !load_error)begin
    load_busy<=0;error_code<=0;
    case(load_kind)
     L_PREVIEW:begin
      cached_mask[write_buf_idx]<=1;
      if(!display_valid)begin display_valid<=1;disp_buf_idx<=write_buf_idx;photo_index<=loading_photo;display_moved=1;end
     end
     L_MANUAL_HD:if(mode==M_MANUAL && !auto_enabled && loading_photo==photo_index && !manual_prev && !manual_next)begin
      disp_buf_idx<=4;display_moved=1;
     end
     L_AUTO_HD:if(mode==M_AUTO && auto_enabled && !stop_auto)begin
      hd_ready<=1;ready_bank<=write_buf_idx;ready_photo<=loading_photo;
     end
     L_HOLD:begin hold_valid[hold_loading]<=1;cached_mask[loading_photo]<=1;end
     L_HOME:begin disp_buf_idx<=write_buf_idx;restore_published<=1;display_moved=1;end
    endcase
   end else if(load_error || load_count>=LOAD_TIMEOUT_CYCLES-1)begin
    load_busy<=0;recover_count<=8;
    error_code<=load_error?bmp_error:8'h41;
    if(load_kind==L_MANUAL_HD || load_kind==L_AUTO_HD)hd_failed[loading_photo]<=1;
    // HOME is retriable: retain the displayed preview on an SD failure.
   end
  end else if(directory_done && sd_init_done && bmp_ready && !engine_rst)begin
   case(mode)
    M_MANUAL:begin
     if(auto_enabled && display_valid && owner_here && !stop_auto)begin
      mode<=M_AUTO;hd_ready<=0;candidate<=following;auto_count<=0;
      // Invalidate, do not physically clear: the visible frame is still protected.
      cached_mask<=current_hd?0:(4'b1<<disp_buf_idx);
     end else if(preload_found)begin
      write_buf_idx<=preload_index;loading_photo<=preload_index;load_kind<=L_PREVIEW;
      load_sector<=sectors[preload_index];attempted_mask[preload_index]<=1;
      load_start_pulse<=1;load_busy<=1;source_seen<=0;finish_seen<=0;
     end else if(display_valid && owner_here && !current_hd && !auto_enabled &&
         !hd_read_busy && !hd_failed[photo_index] && !manual_prev && !manual_next && !key_auto_press)begin
      write_buf_idx<=4;loading_photo<=photo_index;load_kind<=L_MANUAL_HD;
      load_sector<=sectors[photo_index];load_start_pulse<=1;load_busy<=1;
      source_seen<=0;finish_seen<=0;
     end
    end
    M_AUTO:begin
     if(!auto_enabled || stop_auto)begin
      hd_ready<=0;auto_count<=0;
      if(current_hd)begin
       mode<=M_HOLD;hold_valid<=0;hold_attempted<=0;hold_nav<=0;cached_mask<=0;
       hold_photo0<=following;hold_photo1<=preceding;
       hold_bank0<=disp_buf_idx==5?3'd3:3'd0;
       hold_bank1<=disp_buf_idx==5?3'd6:3'd1;
      end else begin
       mode<=M_MANUAL;attempted_mask<=4'b1<<disp_buf_idx;cached_mask<=4'b1<<disp_buf_idx;
      end
     end else if(!hd_ready && owner_here && found_count>1)begin
      if(hd_failed[candidate])candidate<=candidate+1>=found_count?4'd0:candidate+1'b1;
      else if(candidate!=photo_index)begin
       // A bank may be reused only after both display commit and SDRAM ownership move.
       write_buf_idx<=disp_buf_idx==4?3'd5:3'd4;
       loading_photo<=candidate;load_kind<=L_AUTO_HD;load_sector<=sectors[candidate];
       load_start_pulse<=1;load_busy<=1;source_seen<=0;finish_seen<=0;
      end
     end
    end
    M_HOLD:begin
     if(auto_enabled && owner_here && !stop_auto)begin
      mode<=M_AUTO;hd_ready<=0;candidate<=following;hold_valid<=0;auto_count<=0;
     end else if(owner_here && !auto_enabled)begin
      // Keep current HD indefinitely. Only the two adjacent previews are loaded.
      if(!hold_attempted[0] && hold_photo0!=photo_index)begin
       hold_attempted[0]<=1;hold_loading<=0;write_buf_idx<=hold_bank0;
       loading_photo<=hold_photo0;load_sector<=sectors[hold_photo0];load_kind<=L_HOLD;
       load_start_pulse<=1;load_busy<=1;source_seen<=0;finish_seen<=0;
      end else if(!hold_attempted[1] && hold_photo1!=photo_index && hold_photo1!=hold_photo0)begin
       hold_attempted[1]<=1;hold_loading<=1;write_buf_idx<=hold_bank1;
       loading_photo<=hold_photo1;load_sector<=sectors[hold_photo1];load_kind<=L_HOLD;
       load_start_pulse<=1;load_busy<=1;source_seen<=0;finish_seen<=0;
      end
     end
    end
    M_RESTORE:if(owner_here)begin
     if(!restore_published && disp_buf_idx!=photo_index)begin
      write_buf_idx<=photo_index;loading_photo<=photo_index;load_sector<=sectors[photo_index];load_kind<=L_HOME;
      load_start_pulse<=1;load_busy<=1;source_seen<=0;finish_seen<=0;
     end else begin
      mode<=M_MANUAL;cached_mask<=4'b1<<photo_index;attempted_mask<=4'b1<<photo_index;
      hd_failed<=0;restore_published<=0;
     end
    end
   endcase
  end
  if(manual_prev)begin photo_index<=previous_index;disp_buf_idx<=previous_index;auto_count<=0;display_moved=1;end
  else if(manual_next)begin photo_index<=next_index;disp_buf_idx<=next_index;auto_count<=0;display_moved=1;end
  else if(auto_switch)begin
   photo_index<=ready_photo;disp_buf_idx<=ready_bank;hd_ready<=0;auto_count<=0;display_moved=1;
   candidate<=ready_photo+1>=found_count?4'd0:ready_photo+1'b1;
  end else if(mode==M_HOLD && !auto_enabled && settled && hold_hit)begin
   photo_index<=(prev_event || hold_nav==2)?preceding:following;disp_buf_idx<=hold_choice;hold_nav<=0;
   mode<=M_RESTORE;restore_published<=0;auto_count<=0;display_moved=1;
  end
  commit_match<=!display_moved && committed_valid && committed_bank==disp_buf_idx && committed_photo==photo_index;
 end
end

end else if(PROGRESSIVE)begin: progressive_cache
reg [3:0] hd_failed;
reg [3:0] loading_photo;
wire nav_prev=display_valid && fixed_settled && previous_found && EXTERNAL_EVENTS && prev_event;
wire nav_next=display_valid && fixed_settled && next_found && (key_next_press ||
 (auto_enabled && auto_count>=auto_limit && !key_auto_press && !speed_changed && !reset_playback));
always @(posedge clk or posedge rst)begin
 if(rst)begin
  scan_start_pulse<=0;load_start_pulse<=0;scan_kicked<=0;load_sector<=0;load_busy<=0;
  found_count<=0;cached_mask<=0;attempted_mask<=0;display_valid<=0;disp_buf_idx<=0;
  write_buf_idx<=0;photo_index<=0;loading_photo<=0;hd_failed<=0;
  auto_enabled<=0;auto_count<=0;speed_q<=1;load_count<=0;finish_sync<=0;
  source_seen<=0;finish_seen<=0;error_code<=0;recover_count<=0;directory_done<=0;
 end else begin
  speed_q<=speed;finish_sync<={finish_sync[1:0],write_finish_toggle};
  scan_start_pulse<=0;load_start_pulse<=0;
  if(recover_count!=0)recover_count<=recover_count-1'b1;
  if(!scan_kicked && sd_init_done && bmp_ready && !engine_rst)begin scan_start_pulse<=1;scan_kicked<=1;end
  if(scan_done)directory_done<=1;
  if(scan_found_valid && found_count<4)found_count<=found_count+1'b1;
  if(fat_status==3)error_code<=8'h52;
  if(audio_bus_timeout)begin
   recover_count<=8;load_busy<=0;error_code<=8'h41;
   if(write_buf_idx==4)hd_failed[loading_photo]<=1;
  end else if(load_busy)begin
   if(bmp_ready && !load_start_pulse)source_seen<=1;
   if(finish_pulse)finish_seen<=1;
   load_count<=load_count+1'b1;
   if((source_seen || (bmp_ready && !load_start_pulse)) && (finish_seen || finish_pulse) && !load_error)begin
    load_busy<=0;load_count<=0;
    if(write_buf_idx==4)begin
     // Navigation can continue during decode. Discard stale completions.
     if(loading_photo==photo_index && !nav_prev && !nav_next)disp_buf_idx<=4;
    end else begin
     cached_mask[write_buf_idx]<=1;
     if(!display_valid)begin display_valid<=1;disp_buf_idx<=write_buf_idx;photo_index<=write_buf_idx;end
    end
   end else if(load_error || load_count>=LOAD_TIMEOUT_CYCLES-1)begin
    load_busy<=0;load_count<=0;recover_count<=8;
    error_code<=load_error?bmp_error:8'h41;
    if(write_buf_idx==4)hd_failed[loading_photo]<=1;
   end
  end else if(directory_done && sd_init_done && bmp_ready && !engine_rst)begin
   if(preload_found)begin
    write_buf_idx<=preload_index;loading_photo<=preload_index;
    load_sector<=sectors[preload_index];attempted_mask[preload_index]<=1;
    load_start_pulse<=1;load_busy<=1;source_seen<=0;finish_seen<=0;load_count<=0;
   end else if(display_valid && fixed_settled && disp_buf_idx!=4 &&
       committed_bank!=4 && !hd_read_busy && !hd_failed[photo_index] && !nav_prev && !nav_next)begin
    write_buf_idx<=4;loading_photo<=photo_index;load_sector<=sectors[photo_index];
    load_start_pulse<=1;load_busy<=1;source_seen<=0;finish_seen<=0;load_count<=0;
   end
  end
  if(reset_playback)begin auto_enabled<=0;auto_count<=0;end
  else if(speed_changed)auto_count<=0;
  else if(key_auto_press && display_valid)begin auto_enabled<=~auto_enabled;auto_count<=0;end
  // Timed navigation continues while HD decodes; never extend 3 seconds silently.
  else if(auto_enabled && display_valid && !preload_found)begin
   if(auto_count<auto_limit)auto_count<=auto_count+1'b1;
  end else auto_count<=0;
  if(nav_prev)begin photo_index<=previous_index;disp_buf_idx<=previous_index;auto_count<=0;end
  else if(nav_next)begin photo_index<=next_index;disp_buf_idx<=next_index;auto_count<=0;end
 end
end

end else if(!DYNAMIC_CATALOG)begin: fixed_cache
always @* photo_index=disp_buf_idx;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        scan_start_pulse <= 0; load_start_pulse <= 0; scan_kicked <= 0;
        load_sector <= 0; load_busy <= 0; found_count <= 0;
        cached_mask <= 0; attempted_mask <= 0; display_valid <= 0;
        disp_buf_idx <= 0; write_buf_idx <= 0; auto_enabled <= 0;
        auto_count <= 0; speed_q<=1; load_count <= 0; finish_sync <= 0;
        source_seen <= 0; finish_seen <= 0; error_code <= 0;
        recover_count <= 0; directory_done <= 0;
    end else begin
        speed_q<=speed;
        finish_sync <= {finish_sync[1:0],write_finish_toggle};
        scan_start_pulse <= 0;
        load_start_pulse <= 0;
        if (recover_count != 0) recover_count <= recover_count-1'b1;
        if (!scan_kicked && sd_init_done && bmp_ready && !engine_rst) begin
            scan_start_pulse <= 1;
            scan_kicked <= 1;
        end
        if(scan_done) directory_done<=1;
        if(audio_bus_timeout)recover_count<=8;
        if(fat_status==3)error_code<=8'h52;
        if (scan_found_valid && found_count < CACHE_SLOTS) begin
            found_count <= found_count + 1'b1;
        end
        if (load_busy) begin
            if (bmp_ready && !load_start_pulse) source_seen <= 1;
            if (finish_pulse) finish_seen <= 1;
            load_count <= load_count+1'b1;
            // Latch both events: memory completion can precede source EOF.
            if ((source_seen || (bmp_ready && !load_start_pulse)) &&
                (finish_seen || finish_pulse) && !load_error) begin
                cached_mask[write_buf_idx] <= 1;
                if (!display_valid) begin
                    disp_buf_idx <= write_buf_idx;
                    display_valid <= 1;
                end
                load_busy <= 0;
                load_count <= 0;
            end else if (load_error || load_count >= LOAD_TIMEOUT_CYCLES-1) begin
                // Never modify a completed display bank on a failed load.
                load_busy <= 0;
                error_code <= load_error ? bmp_error : 8'h41;
                recover_count <= 8;
                load_count <= 0;
            end
        end else if (directory_done && sd_init_done && bmp_ready && preload_found && !engine_rst) begin
            write_buf_idx <= preload_index;
            load_sector <= sectors[preload_index];
            attempted_mask[preload_index] <= 1;
            load_start_pulse <= 1;
            load_busy <= 1;
            source_seen <= 0;
            finish_seen <= 0;
            load_count <= 0;
        end
        if(reset_playback)begin auto_enabled<=0;auto_count<=0;end
        else if(speed_changed)auto_count<=0;
        else if (key_auto_press && display_valid) begin
            auto_enabled <= ~auto_enabled;
            auto_count <= 0;
        end else if (auto_enabled && display_valid && fixed_settled && !preload_found && !load_busy) begin
            if (auto_count >= auto_limit) auto_count <= 0;
            else auto_count <= auto_count+1'b1;
        end else auto_count <= 0;
        if(display_valid && fixed_settled && previous_found && EXTERNAL_EVENTS && prev_event)begin
            disp_buf_idx<=previous_index;auto_count<=0;
        end else if (display_valid && fixed_settled && next_found &&
            (key_next_press || (auto_enabled && auto_count >= auto_limit && !key_auto_press && !speed_changed && !reset_playback))) begin
            disp_buf_idx <= next_index;
            auto_count <= 0;
        end
    end
end
end else begin: ten_photo_cache
reg [3:0] slot_photo[0:3];
reg [9:0] failed_photos;
reg [3:0] target_photo,loading_photo;
reg [3:0] startup_candidate;
reg demand_pending,loading_demand,demand_reverse;
reg [1:0] victim_cursor;
reg hit,victim_valid;
reg [1:0] hit_slot,victim;
wire [3:0] nav_next=photo_index+1>=found_count?4'd0:photo_index+1'b1;
wire [3:0] nav_prev=photo_index==0?found_count-1'b1:photo_index-1'b1;
integer n,s;
wire settled=!display_valid || (committed_valid && committed_photo==photo_index && committed_bank==disp_buf_idx);
wire auto_due=auto_enabled && auto_count>=auto_limit && !key_auto_press && !speed_changed && !reset_playback;
always @* begin
 hit=0;hit_slot=0;victim_valid=0;victim=0;
 for(n=3;n>=0;n=n-1)begin
  if(cached_mask[n] && slot_photo[n]==target_photo)begin hit=1;hit_slot=n;end
 end
 // Never evict the requested or physically displayed frame, including fades.
 for(n=3;n>=0;n=n-1)begin
  s=(victim_cursor+n)&3;
  if((!display_valid || s!=disp_buf_idx) && (!committed_valid || s!=committed_bank))begin
   victim_valid=1;victim=s;
  end
 end
end
always @(posedge clk or posedge rst)begin
 if(rst)begin
  scan_start_pulse<=0;load_start_pulse<=0;scan_kicked<=0;load_sector<=0;load_busy<=0;
  found_count<=0;cached_mask<=0;attempted_mask<=0;display_valid<=0;disp_buf_idx<=0;write_buf_idx<=0;
  auto_enabled<=0;auto_count<=0;speed_q<=1;load_count<=0;finish_sync<=0;
  source_seen<=0;finish_seen<=0;error_code<=0;recover_count<=0;directory_done<=0;
  photo_index<=0;target_photo<=0;loading_photo<=0;failed_photos<=0;
  demand_pending<=0;loading_demand<=0;demand_reverse<=0;victim_cursor<=0;
  startup_candidate<=4;
  for(j=0;j<4;j=j+1)slot_photo[j]<=j;
 end else begin
  speed_q<=speed;finish_sync<={finish_sync[1:0],write_finish_toggle};
  scan_start_pulse<=0;load_start_pulse<=0;
  if(recover_count!=0)recover_count<=recover_count-1'b1;
  if(!scan_kicked && sd_init_done && bmp_ready && !engine_rst)begin scan_start_pulse<=1;scan_kicked<=1;end
  if(scan_done)directory_done<=1;
  if(audio_bus_timeout)recover_count<=8;
  if(fat_status==3)error_code<=8'h52;
  if(scan_found_valid && found_count<MAX_PHOTOS)begin found_count<=found_count+1'b1;end
  if(load_busy)begin
   if(bmp_ready && !load_start_pulse)source_seen<=1;
   if(finish_pulse)finish_seen<=1;
   load_count<=load_count+1'b1;
   if((source_seen || (bmp_ready && !load_start_pulse)) && (finish_seen || finish_pulse) && !load_error)begin
    cached_mask[write_buf_idx]<=1;slot_photo[write_buf_idx]<=loading_photo;
    load_busy<=0;load_count<=0;error_code<=0;
    if(loading_demand || !display_valid)begin
     disp_buf_idx<=write_buf_idx;photo_index<=loading_photo;display_valid<=1;demand_pending<=0;auto_count<=0;
    end
   end else if(load_error || load_count>=LOAD_TIMEOUT_CYCLES-1)begin
    load_busy<=0;load_count<=0;failed_photos[loading_photo]<=1;demand_pending<=0;
    error_code<=load_error?bmp_error:8'h41;recover_count<=8;
   end
  end else if(directory_done && sd_init_done && bmp_ready && !engine_rst)begin
   if(demand_pending)begin
    if(failed_photos[target_photo])begin
     // Skip one known-bad file per cycle, keeping the 100 MHz path short.
     if(demand_reverse)target_photo<=target_photo==0?found_count-1'b1:target_photo-1'b1;
     else target_photo<=target_photo+1>=found_count?4'd0:target_photo+1'b1;
    end else if(hit)begin
     disp_buf_idx<=hit_slot;photo_index<=target_photo;display_valid<=1;demand_pending<=0;auto_count<=0;
    end else if(victim_valid)begin
     write_buf_idx<=victim;cached_mask[victim]<=0;victim_cursor<=victim+1'b1;
     loading_photo<=target_photo;load_sector<=sectors[target_photo];loading_demand<=1;
     load_start_pulse<=1;load_busy<=1;source_seen<=0;finish_seen<=0;load_count<=0;
    end
   end else if(preload_found)begin
    // Four initial slots preserve fast cached navigation and bound startup work.
    write_buf_idx<=preload_index;loading_photo<={2'd0,preload_index};
    load_sector<=sectors[preload_index];attempted_mask[preload_index]<=1;loading_demand<=0;
    load_start_pulse<=1;load_busy<=1;source_seen<=0;finish_seen<=0;load_count<=0;
   end else if(!display_valid && startup_candidate<found_count)begin
    // If the first four files are unreadable, continue to the next catalog entry.
    target_photo<=startup_candidate;startup_candidate<=startup_candidate+1'b1;
    demand_pending<=1;demand_reverse<=0;
   end
  end
  if(reset_playback)begin auto_enabled<=0;auto_count<=0;end
  else if(speed_changed)auto_count<=0;
  else if(key_auto_press && display_valid)begin auto_enabled<=~auto_enabled;auto_count<=0;end
  else if(auto_enabled && display_valid && settled && !load_busy && !demand_pending)begin
   if(auto_count<auto_limit)auto_count<=auto_count+1'b1;
  end else auto_count<=0;
  // Serialize navigation until the last frame is committed; held keys are debounced upstream.
  if(display_valid && settled && !load_busy && !demand_pending && !preload_found)begin
   if(EXTERNAL_EVENTS && prev_event)begin target_photo<=nav_prev;demand_pending<=1;demand_reverse<=1;auto_count<=0;end
   else if(key_next_press || auto_due)begin target_photo<=nav_next;demand_pending<=1;demand_reverse<=0;auto_count<=0;end
  end
 end
end
end endgenerate
fat_bmp_read #(.MAX_PHOTOS(MAX_PHOTOS)) bmp_read_m0(
    .clk(clk),.rst(rst),.decoder_rst(engine_rst),.ready(bmp_ready),.fat_status(fat_status),
    .scan_start(scan_start_pulse),.scan_start_sector(SCAN_START_SECTOR),
    .scan_max_sector(SCAN_MAX_SECTOR),.scan_target_count(SCAN_TARGET_COUNT),
    .scan_done(scan_done),.scan_found_valid(scan_found_valid),
    .scan_found_sector(scan_found_sector),.scan_found_total(scan_found_total),
    .load_start(load_start_pulse),.load_sector(load_sector),
    .sd_init_done(sd_init_done),.state_code(state_code),
    .bmp_width(PROGRESSIVE && (write_buf_idx==4 || write_buf_idx==5)?16'd1024:bmp_width),.bmp_height(PROGRESSIVE && (write_buf_idx==4 || write_buf_idx==5)?16'd768:bmp_height),
    .write_req(write_req),.write_req_ack(write_req_ack),
    .sd_sec_read(sd_sec_read),.sd_sec_read_addr(sd_sec_read_addr),
    .sd_sec_read_data(sd_sec_read_data),.sd_sec_read_data_valid(sd_sec_read_data_valid),
    .sd_sec_read_end(sd_sec_read_end),.bmp_data_wr_en(bmp_data_wr_en),.bmp_data(bmp_data),
    .load_error(load_error),.bmp_error(bmp_error)
);
wire card_req,card_valid,card_end;wire [31:0] card_lba;wire [7:0] card_data;
wire audio_req,audio_valid,audio_end,bus_idle;wire [31:0] audio_lba;
// Preload completion is stable before music starts; register its wide decode.
reg media_loaded;
always @(posedge clk or posedge engine_rst)begin
 if(engine_rst)media_loaded<=0;
 else if(directory_done && !load_busy && (!preload_found || (SLIDESHOW_HD && display_valid)) && bmp_ready && fat_status==2)media_loaded<=1;
end
generate if(ENABLE_SD_AUDIO)begin: sd_music
 sd_read_arbiter arb(.clk(clk),.rst(engine_rst),.a_req(sd_sec_read),.a_lba(sd_sec_read_addr),
  .b_req(audio_req),.b_lba(audio_lba),.card_data(card_data),.card_valid(card_valid),.card_end(card_end),.data(sd_sec_read_data),
  .a_valid(sd_sec_read_data_valid),.a_end(sd_sec_read_end),.b_valid(audio_valid),.b_end(audio_end),
  .card_req(card_req),.card_lba(card_lba),.idle(bus_idle),.timeout(audio_bus_timeout));
 sd_wav_player #(.ENABLE_WAV(ENABLE_SD_WAV)) player(.clk(clk),.rst(engine_rst),.allow(media_loaded),.sd_ready(sd_init_done),.bus_idle(bus_idle),
  .track(music_track),.play(music_play),.track_count(music_count),.status(music_status),.error_code(music_error),
  .sector_req(audio_req),.sector_lba(audio_lba),.sector_data(sd_sec_read_data),.sector_valid(audio_valid),.sector_end(audio_end),
  .pixel_clk(pixel_clk),.pixel_rst(pixel_rst),.audio_tick(audio_tick),.play_pixel(audio_play_pixel),
  .left_pcm(sd_audio_left),.right_pcm(sd_audio_right));
end else begin
 assign card_req=sd_sec_read;assign card_lba=sd_sec_read_addr;
 assign sd_sec_read_data=card_data;assign sd_sec_read_data_valid=card_valid;assign sd_sec_read_end=card_end;
 assign audio_bus_timeout=0;assign music_count=0;assign music_status=0;assign music_error=0;
 assign sd_audio_left=0;assign sd_audio_right=0;
end endgenerate
sd_card_top sd_card_top_m0(
    .clk(clk),.rst(engine_rst),.SD_nCS(SD_nCS),.SD_DCLK(SD_DCLK),
    .SD_MOSI(SD_MOSI),.SD_MISO(SD_MISO),.sd_init_done(sd_init_done),
    .sd_sec_read(card_req),.sd_sec_read_addr(card_lba),
    .sd_sec_read_data(card_data),.sd_sec_read_data_valid(card_valid),
    .sd_sec_read_end(card_end),.sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),
    .sd_sec_write_data(),.sd_sec_write_data_req(),.sd_sec_write_end()
);
endmodule
