// Actual accepted PCM only. 128 slots leave 32 spare while copying 96 entries.
module audio_ring_levels #(parameter integer BAR_COUNT=96)(
 input wire clk, rst, frame_start, pcm_valid,
 input wire signed [15:0] pcm_left, pcm_right,
 input wire [6:0] bar_index,
 output wire [4:0] bar_height
);
 wire [15:0] left_abs = pcm_left[15] ? (~pcm_left + 16'd1) : pcm_left;
 wire [15:0] right_abs = pcm_right[15] ? (~pcm_right + 16'd1) : pcm_right;
 wire [15:0] magnitude = left_abs > right_abs ? left_abs : right_abs;
 reg [15:0] peak;
 wire [15:0] next_peak = magnitude > peak ? magnitude : peak;
 wire [4:0] level = next_peak[15:9] > 28 ? 5'd28 : next_peak[13:9];
 reg [4:0] sample_count;
 reg [6:0] write_pointer, history_count;
 reg [4:0] history [0:127];
 // Heights live in two identically written distributed RAMs: one read by the
 // display, one by the copy update. Copies always write 0,1,2... so the
 // entries written since reset form a prefix; the rest read as reset zero.
 reg [4:0] display_heights [0:BAR_COUNT-1];
 reg [4:0] update_heights [0:BAR_COUNT-1];
 reg [6:0] filled;
 reg seen_sample;
 reg copying, copy_valid, copy_zero;
 reg [6:0] copy_pointer, copy_index, missing, result_index;
 reg [4:0] history_q;
 reg result_zero;
 wire [4:0] old_height = result_index < filled ? update_heights[result_index] : 5'd0;
 reg [4:0] new_height;
 assign bar_height = bar_index < filled ? display_heights[bar_index] : 5'd0;
 always @* begin
  if(!result_zero && history_q >= old_height) new_height = history_q;
  else if(old_height>3) begin
   if(!result_zero && history_q > old_height-5'd3) new_height = history_q;
   else new_height = old_height-5'd3;
  end else new_height = result_zero ? 5'd0 : history_q;
 end
 // Read port has a synchronous RAM latency; unwritten entries are masked.
 wire [6:0] history_read_address;
 // TD18 and TD30 exposed distinct short bits of this direct BRAM address.
 // Match their combinational delay without changing the synchronous read.
 genvar address_bit;
 generate for(address_bit=0;address_bit<7;address_bit=address_bit+1)begin:g_copy_hold
  (* keep="true" *) AL_MAP_LUT1 #(.INIT(2'b10),.EQN("A"))
   u_hold(.o(history_read_address[address_bit]),.a(copy_pointer[address_bit]));
 end endgenerate
 always @(posedge clk) history_q <= history[history_read_address];
 always @(posedge clk) begin
  if (pcm_valid && !rst && sample_count == 31) history[write_pointer] <= level;
 end
 always @(posedge clk) begin
  if (copy_valid && !rst) begin
   display_heights[result_index] <= new_height;
   update_heights[result_index] <= new_height;
  end
 end
 always @(posedge clk or posedge rst) begin
  if (rst) begin
   peak<=0; sample_count<=0; write_pointer<=0; history_count<=0; seen_sample<=0;
   copying<=0; copy_valid<=0; copy_zero<=1; copy_pointer<=0; copy_index<=0;
   missing<=BAR_COUNT; result_index<=0; result_zero<=1; filled<=0;
  end else begin
   if(pcm_valid) begin
    seen_sample<=1;
    if(sample_count==31) begin
     peak<=0; sample_count<=0; write_pointer<=write_pointer+1'b1;
     if(history_count<BAR_COUNT) history_count<=history_count+1'b1;
    end else begin peak<=next_peak; sample_count<=sample_count+1'b1; end
   end
   if(frame_start) begin
    seen_sample<=pcm_valid;
    copying<=1; copy_pointer<=write_pointer-BAR_COUNT; copy_index<=0;
    missing<=BAR_COUNT-history_count; copy_zero<=!seen_sample;
   end else if(copying) begin
    copy_pointer<=copy_pointer+1'b1;
    if(copy_index==BAR_COUNT-1) copying<=0;
    else copy_index<=copy_index+1'b1;
   end
   copy_valid<=copying;
   result_index<=copy_index;
   result_zero<=copy_zero || copy_index<missing;
   if(copy_valid && result_index==filled) filled<=filled+1'b1;
  end
 end
endmodule
