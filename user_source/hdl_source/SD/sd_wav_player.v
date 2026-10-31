// FAT32 WAV player: independent catalog, bounded parser, elastic stereo FIFO.
// SD domain commands are flushed on every stop/track change. Video domain uses
// the existing 48 kHz HDMI cadence, never a new audio clock or independent PLL.
module sd_wav_player #(parameter integer RAW_PCM_CHANNELS=1,ENABLE_WAV=1,LOOP_PLAYBACK=1)(
 input clk,rst,allow,sd_ready,bus_idle,input [2:0] track,input play,
 output [2:0] track_count,output reg [2:0] status,output reg [7:0] error_code,
 output sector_req,output [31:0] sector_lba,input [7:0] sector_data,input sector_valid,sector_end,
 input pixel_clk,pixel_rst,audio_tick,play_pixel,output [23:0] left_pcm,right_pcm);
localparam MOUNT=0,MOUNT_WAIT=1,IDLE=2,DRAIN=3,CLEAR=4,LOAD=5,ARM=6,RUN=7,ENDED=8,FAILED=9;
reg [3:0] state;reg [5:0] delay_count;
reg mount_start,load_start,abort_load,decoder_rst,decoder_start,fifo_reset;
reg [2:0] selected;reg play_q;
wire mount_done,map_error;wire [1:0] fat_status;
wire [7:0] fs_error,vdata;
wire [31:0] file_bytes,vlba;
wire raw_pcm;
wire vreq,vvalid,vend,decoder_valid,decoder_done,decoder_error,format_valid;
wire [7:0] decoder_code;
wire [31:0] decoder_pcm,fifo_data;
wire fifo_full,fifo_empty;wire [11:0] wr_level,rd_level;
wire config_changed=track!=selected || play!=play_q;
// Registered request: track/play changes are also caught by config_changed.
reg wanted;
fat32_wav_map #(.INCLUDE_WAV(ENABLE_WAV)) fs(.clk(clk),.rst(rst),.abort_load(abort_load),.sd_ready(sd_ready),
 .mount_start(mount_start),.mount_done(mount_done),.found_valid(),.found_token(),.found_count(track_count),.fat_status(fat_status),
 .load_start(load_start),.file_index(selected[1:0]-2'd1),.virtual_req(vreq),.virtual_lba(vlba),
 .virtual_data(vdata),.virtual_valid(vvalid),.virtual_end(vend),.load_error(map_error),.fs_error(fs_error),
 .sector_req(sector_req),.sector_lba(sector_lba),.sector_data(sector_data),.sector_valid(sector_valid),.sector_done(sector_end),.file_bytes(file_bytes),.raw_pcm(raw_pcm));
wav_pcm_reader #(.RAW_PCM_CHANNELS(RAW_PCM_CHANNELS),.RAW_ONLY(!ENABLE_WAV)) decoder(.clk(clk),.rst(decoder_rst || rst),.start(decoder_start),.file_bytes(file_bytes),.raw_pcm(raw_pcm),
 .sector_req(vreq),.sector_lba(vlba),.sector_data(vdata),.sector_valid(vvalid),.sector_end(vend),
 .pcm_data(decoder_pcm),.pcm_valid(decoder_valid),.pcm_ready(!fifo_full),
 .format_valid(format_valid),.done(decoder_done),.error(decoder_error),.error_code(decoder_code));
// Reset is asserted by a registered source signal and released on read clocks.
wire read_reset_request=fifo_reset || rst || pixel_rst;
reg [2:0] reset_sync;
always @(posedge pixel_clk or posedge read_reset_request)begin
 if(read_reset_request)reset_sync<=7;else reset_sync<={reset_sync[1:0],1'b0};
end
wire read_rst=reset_sync[2];
reg eof_meta,eof_sync,read_active;
reg active_meta,active_sync;
wire read_take=audio_tick && play_pixel && read_active && !fifo_empty;
pcm_async_fifo fifo(.wr_clk(clk),.wr_rst(fifo_reset || rst),.wr_en(decoder_valid && !decoder_rst),
 .wr_data(decoder_pcm),.wr_full(fifo_full),.wr_level(wr_level),
 .rd_clk(pixel_clk),.rd_rst(read_rst),.rd_en(read_take),.rd_data(fifo_data),.rd_empty(fifo_empty),.rd_level(rd_level));
assign left_pcm=read_active && !fifo_empty && !read_rst && play_pixel?{fifo_data[31:16],8'd0}:24'd0;
assign right_pcm=read_active && !fifo_empty && !read_rst && play_pixel?{fifo_data[15:0],8'd0}:24'd0;
always @(posedge pixel_clk or posedge read_rst)begin
 if(read_rst)begin eof_meta<=0;eof_sync<=0;read_active<=0;end
 else begin
  eof_meta<=decoder_done;eof_sync<=eof_meta;
  if(!play_pixel)read_active<=0;
  else if(!read_active && (rd_level>=256 || (eof_sync && !fifo_empty)))read_active<=1;
  else if(audio_tick && fifo_empty)read_active<=0;
 end
end
always @(posedge clk or posedge rst)begin
 if(rst)begin active_meta<=0;active_sync<=0;end
 else begin active_meta<=read_active;active_sync<=active_meta;end
end
always @(posedge clk or posedge rst)begin
 if(rst)begin
  state<=MOUNT;mount_start<=0;load_start<=0;abort_load<=0;decoder_rst<=1;decoder_start<=0;fifo_reset<=1;
  selected<=0;play_q<=0;status<=0;error_code<=0;delay_count<=0;wanted<=0;
 end else begin
  mount_start<=0;load_start<=0;decoder_start<=0;
  wanted<=play && track!=0 && track<=track_count;
  case(state)
   MOUNT:if(allow && sd_ready && bus_idle)begin mount_start<=1;state<=MOUNT_WAIT;end
   MOUNT_WAIT:if(mount_done)begin
    if(fat_status==2)begin status<=0;state<=IDLE;end
    else begin error_code<=8'h60;status<=4;state<=FAILED;selected<=track;play_q<=play;end
   end
   IDLE:begin
    selected<=track;play_q<=play;fifo_reset<=1;decoder_rst<=1;abort_load<=1;
    if(wanted && allow && sd_ready)begin state<=DRAIN;status<=1;error_code<=0;end
   end
   DRAIN:begin
    fifo_reset<=1;decoder_rst<=1;abort_load<=1;
    selected<=track;play_q<=play;
    if(bus_idle && !sector_req)begin delay_count<=32;state<=CLEAR;end
   end
   CLEAR:if(config_changed)state<=DRAIN;
    else if(delay_count!=0)delay_count<=delay_count-1'b1;
    else if(wanted && allow && sd_ready && fat_status==2)begin
     fifo_reset<=0;abort_load<=0;decoder_rst<=0;state<=LOAD;
    end else begin state<=IDLE;status<=0;end
   LOAD:begin load_start<=1;delay_count<=6;state<=ARM;end
   ARM:if(delay_count!=0)delay_count<=delay_count-1'b1;
    else begin decoder_start<=1;state<=RUN;end
   RUN:begin
    status<=active_sync?2:1;
    if(decoder_done && wr_level==0)begin status<=3;state<=ENDED;end
    if(map_error || decoder_error)begin
     error_code<=map_error?fs_error:decoder_code;status<=4;state<=FAILED;
     fifo_reset<=1;decoder_rst<=1;abort_load<=1;
    end
   end
   ENDED:begin
    status<=3;
    if(LOOP_PLAYBACK && wanted && allow && sd_ready)begin
     state<=DRAIN;fifo_reset<=1;decoder_rst<=1;abort_load<=1;status<=1;
    end
   end
   FAILED:status<=4;
  endcase
  if(state>=LOAD && config_changed)begin
   state<=DRAIN;fifo_reset<=1;decoder_rst<=1;abort_load<=1;status<=0;error_code<=0;
  end
 end
end
endmodule
