begin: slideshow_cache
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
wire owner_here=reader_owned[disp_buf_idx] && fixed_settled;
wire [3:0] following=(photo_index+1>=found_count)?4'd0:photo_index+1'b1;
wire [3:0] preceding=photo_index==0?found_count-1'b1:photo_index-1'b1;
wire auto_due=auto_count>=auto_limit && !key_auto_press && !speed_changed && !reset_playback;
wire auto_switch=mode==M_AUTO && auto_enabled && fixed_settled && hd_ready &&
 (auto_due || key_next_press) && !key_auto_press && !reset_playback && !prev_event;
wire manual_prev=mode==M_MANUAL && !auto_enabled && display_valid && fixed_settled && previous_found && prev_event;
wire manual_next=mode==M_MANUAL && !auto_enabled && display_valid && fixed_settled && next_found && key_next_press;
wire stop_auto=reset_playback || prev_event || (key_auto_press && auto_enabled);
reg [2:0] hold_choice;
reg hold_hit;
always @* begin
 hold_hit=0;hold_choice=0;
 if(hold_valid[0] && (((key_next_press || hold_nav==1) && hold_photo0==following) || ((prev_event || hold_nav==2) && hold_photo0==preceding)))begin
  hold_hit=1;hold_choice=hold_bank0;
 end
 if(hold_valid[1] && (((key_next_press || hold_nav==1) && hold_photo1==following) || ((prev_event || hold_nav==2) && hold_photo1==preceding)))begin
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
 end else begin
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
  else if(auto_enabled && display_valid && fixed_settled)begin
   if(auto_count<auto_limit)auto_count<=auto_count+1'b1;
  end

  if(audio_bus_timeout)begin
   recover_count<=8;load_busy<=0;error_code<=8'h41;
   if(load_kind==L_MANUAL_HD || load_kind==L_AUTO_HD)hd_failed[loading_photo]<=1;
  end else if(load_busy)begin
   if(bmp_ready && !load_start_pulse)source_seen<=1;
   if(finish_pulse)finish_seen<=1;
   load_count<=load_count+1'b1;
   if((source_seen || (bmp_ready && !load_start_pulse)) && (finish_seen || finish_pulse) && !load_error)begin
    load_busy<=0;load_count<=0;error_code<=0;
    case(load_kind)
     L_PREVIEW:begin
      cached_mask[write_buf_idx]<=1;
      if(!display_valid)begin display_valid<=1;disp_buf_idx<=write_buf_idx;photo_index<=loading_photo;end
     end
     L_MANUAL_HD:if(mode==M_MANUAL && !auto_enabled && loading_photo==photo_index && !manual_prev && !manual_next)disp_buf_idx<=4;
     L_AUTO_HD:if(mode==M_AUTO && auto_enabled && !stop_auto)begin
      hd_ready<=1;ready_bank<=write_buf_idx;ready_photo<=loading_photo;
     end
     L_HOLD:begin hold_valid[hold_loading]<=1;cached_mask[loading_photo]<=1;end
     L_HOME:begin disp_buf_idx<=write_buf_idx;restore_published<=1;end
    endcase
   end else if(load_error || load_count>=LOAD_TIMEOUT_CYCLES-1)begin
    load_busy<=0;load_count<=0;recover_count<=8;
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
      load_start_pulse<=1;load_busy<=1;source_seen<=0;finish_seen<=0;load_count<=0;
     end else if(display_valid && owner_here && !current_hd && !auto_enabled &&
         !hd_read_busy && !hd_failed[photo_index] && !manual_prev && !manual_next && !key_auto_press)begin
      write_buf_idx<=4;loading_photo<=photo_index;load_kind<=L_MANUAL_HD;
      load_sector<=sectors[photo_index];load_start_pulse<=1;load_busy<=1;
      source_seen<=0;finish_seen<=0;load_count<=0;
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
       load_start_pulse<=1;load_busy<=1;source_seen<=0;finish_seen<=0;load_count<=0;
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
       load_start_pulse<=1;load_busy<=1;source_seen<=0;finish_seen<=0;load_count<=0;
      end else if(!hold_attempted[1] && hold_photo1!=photo_index && hold_photo1!=hold_photo0)begin
       hold_attempted[1]<=1;hold_loading<=1;write_buf_idx<=hold_bank1;
       loading_photo<=hold_photo1;load_sector<=sectors[hold_photo1];load_kind<=L_HOLD;
       load_start_pulse<=1;load_busy<=1;source_seen<=0;finish_seen<=0;load_count<=0;
      end
     end
    end
    M_RESTORE:if(owner_here)begin
     if(!restore_published && disp_buf_idx!=photo_index)begin
      write_buf_idx<=photo_index;loading_photo<=photo_index;load_sector<=sectors[photo_index];load_kind<=L_HOME;
      load_start_pulse<=1;load_busy<=1;source_seen<=0;finish_seen<=0;load_count<=0;
     end else begin
      mode<=M_MANUAL;cached_mask<=4'b1<<photo_index;attempted_mask<=4'b1<<photo_index;
      hd_failed<=0;restore_published<=0;
     end
    end
   endcase
  end
  if(manual_prev)begin photo_index<=previous_index;disp_buf_idx<=previous_index;auto_count<=0;end
  else if(manual_next)begin photo_index<=next_index;disp_buf_idx<=next_index;auto_count<=0;end
  else if(auto_switch)begin
   photo_index<=ready_photo;disp_buf_idx<=ready_bank;hd_ready<=0;auto_count<=0;
   candidate<=ready_photo+1>=found_count?4'd0:ready_photo+1'b1;
  end else if(mode==M_HOLD && !auto_enabled && fixed_settled && hold_hit)begin
   photo_index<=(prev_event || hold_nav==2)?preceding:following;disp_buf_idx<=hold_choice;hold_nav<=0;
   mode<=M_RESTORE;restore_published<=0;auto_count<=0;
  end
 end
end

