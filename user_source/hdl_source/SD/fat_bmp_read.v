// FAT discovery and sector remapping with a sequential aspect-fit BMP decoder.
module fat_bmp_read #(parameter MAX_PHOTOS=10)(
 input clk,rst,decoder_rst,output ready,input scan_start,
 input [31:0] scan_start_sector,scan_max_sector,input [3:0] scan_target_count,
 output scan_done,scan_found_valid,output [31:0] scan_found_sector,output [3:0] scan_found_total,
 input load_start,input [31:0] load_sector,input sd_init_done,output [3:0] state_code,
 input [15:0] bmp_width,bmp_height,output write_req,input write_req_ack,
 output sd_sec_read,output [31:0] sd_sec_read_addr,input [7:0] sd_sec_read_data,
 input sd_sec_read_data_valid,sd_sec_read_end,output bmp_data_wr_en,output [23:0] bmp_data,
 output load_error,output [7:0] bmp_error,output [1:0] fat_status);
wire map_req,map_done,map_found,map_end,map_valid,map_error;
wire [31:0] map_lba,map_token;wire [3:0] map_count;wire [7:0] map_data,fs_error;
wire raw_req,raw_done,raw_found,raw_ready,raw_error;wire [31:0] raw_lba,raw_token;
wire [3:0] raw_count;wire [7:0] raw_err;
reg scanning,raw_scan_start;reg [3:0] index;
// The FAT map sees the load one cycle late, from registers only. The decoder
// needs two more cycles before its first virtual sector request.
reg map_load_start;
wire raw_mode=fat_status==1;
always @(posedge clk or posedge rst)begin
 if(rst)begin scanning<=0;raw_scan_start<=0;index<=0;map_load_start<=0;end
 else begin
  raw_scan_start<=0;map_load_start<=load_start;
  if(scan_start)scanning<=1;
  if(scanning && map_done)begin scanning<=0;if(raw_mode)raw_scan_start<=1;end
  if(load_start)index<=load_sector[3:0];
 end
end
// Registered decoder reset: no combinational logic drives asynchronous resets.
reg decoder_reset;
always @(posedge clk or posedge rst)begin
 if(rst)decoder_reset<=1;
 else decoder_reset<=decoder_rst || map_error;
end
assign ready=raw_ready && !scanning && !raw_scan_start;
assign scan_done=raw_mode?raw_done:map_done;
assign scan_found_valid=raw_mode?raw_found:map_found;
assign scan_found_sector=raw_mode?raw_token:map_token;
assign scan_found_total=raw_mode?raw_count:map_count;
assign sd_sec_read=raw_mode?raw_req:map_req;
assign sd_sec_read_addr=raw_mode?raw_lba:map_lba;
assign load_error=raw_error || map_error;
assign bmp_error=map_error?fs_error:raw_err;
fat32_sector_map #(.MAX_PHOTOS(MAX_PHOTOS)) fs(.clk(clk),.rst(rst),.abort_load(decoder_rst),.sd_ready(sd_init_done),
 .mount_start(scan_start),.mount_done(map_done),.found_valid(map_found),.found_token(map_token),
 .found_count(map_count),.fat_status(fat_status),.load_start(map_load_start),.file_index(index),
 .virtual_req(raw_req),.virtual_lba(raw_lba),.virtual_data(map_data),.virtual_valid(map_valid),
 .virtual_end(map_end),.load_error(map_error),.fs_error(fs_error),
 .sector_req(map_req),.sector_lba(map_lba),.sector_data(sd_sec_read_data),
 .sector_valid(sd_sec_read_data_valid),.sector_done(sd_sec_read_end));
// Pipeline the complete byte stream together. FAT checks no longer feed
// the header-register enables through a long combinational valid path.
// End follows the final byte by the same one-cycle delay in both modes.
reg [7:0] decoder_data_q;
reg decoder_valid_q,decoder_end_q;
always @(posedge clk or posedge rst)begin
 if(rst)begin decoder_data_q<=0;decoder_valid_q<=0;decoder_end_q<=0;end
 else if(decoder_rst || map_error)begin decoder_data_q<=0;decoder_valid_q<=0;decoder_end_q<=0;end
 else begin
  decoder_data_q<=raw_mode?sd_sec_read_data:map_data;
  decoder_valid_q<=raw_mode?sd_sec_read_data_valid:map_valid;
  decoder_end_q<=raw_mode?sd_sec_read_end:map_end;
 end
end
bmp_fit_read decoder(.clk(clk),.rst(decoder_reset),.ready(raw_ready),
 .scan_start(raw_scan_start),.scan_start_sector(scan_start_sector),.scan_max_sector(scan_max_sector),
 .scan_target_count(scan_target_count),.scan_done(raw_done),.scan_found_valid(raw_found),
 .scan_found_sector(raw_token),.scan_found_total(raw_count),.load_start(load_start),
 .load_sector(raw_mode?load_sector:32'd0),.sd_init_done(sd_init_done),.state_code(state_code),
 .bmp_width(bmp_width),.bmp_height(bmp_height),.write_req(write_req),.write_req_ack(write_req_ack),
 .sd_sec_read(raw_req),.sd_sec_read_addr(raw_lba),
 .sd_sec_read_data(decoder_data_q),
 .sd_sec_read_data_valid(decoder_valid_q),
 .sd_sec_read_end(decoder_end_q),
 .bmp_data_wr_en(bmp_data_wr_en),.bmp_data(bmp_data),.load_error(raw_error),.bmp_error(raw_err));
endmodule

// Kept in this already-registered source so older TD project lists remain valid.
module bmp_fit_read(
    input                       clk,
    input                       rst,
    output reg                  ready,

    // 上电扫描：从 scan_start_sector 开始，顺序寻找前 scan_target_count 张 BMP
    input                       scan_start,
    input  [31:0]               scan_start_sector,
    input  [31:0]               scan_max_sector,
    input  [3:0]                scan_target_count,
    output reg                  scan_done,
    output reg                  scan_found_valid,
    output reg [31:0]           scan_found_sector,
    output reg [3:0]            scan_found_total,

    // 按指定扇区加载一张图到 SDRAM
    input                       load_start,
    input  [31:0]               load_sector,

    input                       sd_init_done,
    output reg [3:0]            state_code,
    input  [15:0]               bmp_width,
    input  [15:0]               bmp_height,

    output reg                  write_req,
    input                       write_req_ack,

    output reg                  sd_sec_read,
    output reg [31:0]           sd_sec_read_addr,
    input  [7:0]                sd_sec_read_data,
    input                       sd_sec_read_data_valid,
    input                       sd_sec_read_end,

    output reg                  bmp_data_wr_en,
    output reg [23:0]           bmp_data,
    output reg load_error,
    output reg [7:0] bmp_error
);

// Sequential sector consumption with one original-resolution scanline in BRAM.
// All frames are emitted bottom-up to the existing vertical-flip SDRAM writer.
// Output is paced to no more than one pixel per 64 SD-clock cycles.
localparam IDLE=0,FETCH=1,WAIT_SECTOR=2,HEADER_SETTLE=3,HEADER_CHECK=4,
 GEOMETRY=5,DIVIDE=6,FIT_READY=7,WRITE_ACK=8,STREAM_ADDR=9,STREAM_BYTE=10,
 ROW_DONE=11,OUT_ADDR=12,OUT_PIXEL=13,OUT_PACE=14,X_STEP=15,Y_STEP=16,
 ROW_NEXT=17,FINISH=18,BUFFER_READY=19,WRITE_DRAIN=20,X_APPLY=21,Y_APPLY=22,
 ROW_EVAL=23;
reg [4:0] state,fetch_return;
reg [7:0] sector_mem[0:511];
reg [23:0] row_mem[0:4095];
reg [8:0] rx_index,byte_index;
reg [7:0] byte_q;
reg [23:0] row_q;
reg header_fetch,scanning;
reg [31:0] file_len,pixel_offset,width,height,dib_size,compression;
reg [15:0] signature,planes,bit_count;
reg [31:0] scan_sector,load_base,file_pos;
reg [31:0] file_sectors,scan_next;
reg [14:0] stride,row_byte,row_payload;
reg [27:0] payload_size;
reg [22:0] width480,height640;
reg header_ok;
reg [1:0] settle,component;
reg [15:0] bgr;
reg [12:0] src_x,src_y,target_y,sample_x;
reg [10:0] fit_w,fit_h,pad_x,pad_y,out_x,out_y,image_y;
reg [22:0] dividend;
reg [12:0] divisor;
reg [10:0] quotient;
reg wide_image,image_row;
reg [13:0] x_error,y_error;
reg [13:0] step_remainder;
reg step_again;
reg [5:0] pace;
reg ack_meta,ack_sync;
reg [10:0] image_right;
reg [10:0] image_top;
// Registered decisions. Each is consumed only after a cycle in which its
// operands do not change: STREAM_ADDR/BUFFER_READY precede STREAM_BYTE,
// STREAM_BYTE precedes ROW_DONE and ROW_EVAL precedes ROW_NEXT.
// OUT_ADDR precedes OUT_PIXEL, and OUT_PACE waits 63 cycles (3.0 timing).
reg stream_pixel,stream_payload,stream_row_end,row_hit;
reg row_past_end,row_margin,row_repeat,out_inside,out_last;
// Stream position flags are updated with file_pos itself (FIT_READY and
// STREAM_BYTE), so STREAM_ADDR needs no 32-bit compare (3.0 timing).
reg [31:0] file_len_m1;
reg pos_at_end,pos_sector;
always @(posedge clk) begin
 if(state==WAIT_SECTOR && sd_sec_read_data_valid)sector_mem[rx_index]<=sd_sec_read_data;
 byte_q<=sector_mem[byte_index];
 if(state==STREAM_BYTE && stream_pixel && stream_payload && component==2)
  row_mem[src_x[11:0]]<={byte_q,bgr};
 row_q<=row_mem[sample_x[11:0]];
end
always @(posedge clk or posedge rst) begin
 if(rst)begin
  image_right<=0;image_top<=0;ack_meta<=0;ack_sync<=0;stride<=0;row_payload<=0;payload_size<=0;width480<=0;height640<=0;
  file_sectors<=0;scan_next<=0;header_ok<=0;
  stream_pixel<=0;stream_payload<=0;stream_row_end<=0;row_hit<=0;
  row_past_end<=0;row_margin<=0;row_repeat<=0;out_inside<=0;out_last<=0;file_len_m1<=0;
 end else begin
  out_inside<=image_row && out_x>=pad_x && out_x<image_right;
  file_len_m1<=file_len-1'b1;
  out_last<=out_x==bmp_width-1;
  image_right<=pad_x+fit_w;image_top<=pad_y+fit_h;
  stream_pixel<=file_pos>=pixel_offset && src_y<height;
  stream_payload<=row_byte<row_payload;
  stream_row_end<=row_byte+1'b1==stride;
  row_hit<=src_y==target_y && image_y<fit_h;
  row_past_end<=out_y>=bmp_height;
  row_margin<=out_y<pad_y || out_y>=image_top;
  row_repeat<=image_row && target_y==src_y-1'b1;
  ack_meta<=write_req_ack;ack_sync<=ack_meta;
  row_payload<=width[12:0]*15'd3;
  stride<=((width[12:0]*15'd3)+15'd3)&15'h7ffc;
  payload_size<=stride*height[12:0];
  width480<=width[12:0]*bmp_height[10:0];height640<=height[12:0]*bmp_width[10:0];
  file_sectors<={9'd0,file_len[31:9]}+{31'd0,|file_len[8:0]};
  scan_next<=scan_sector+file_sectors;
  header_ok<=signature==16'h4d42 && width>=1 && width<=4096 && height>=1 && height<=4096 &&
   planes==1 && bit_count==24 && compression==0 && dib_size>=40 &&
   pixel_offset>=54 && pixel_offset<=4096 && file_len>=pixel_offset &&
   file_len-pixel_offset>=payload_size && ((bmp_width==640 && bmp_height==480) || (bmp_width==1024 && bmp_height==768));
 end
end
// Parse only the first sector, independently from the buffered pixel stream.
always @(posedge clk or posedge rst) begin
 if(rst)begin signature<=0;file_len<=0;pixel_offset<=0;width<=0;height<=0;
  dib_size<=0;planes<=0;bit_count<=0;compression<=0;end
 else if(state==WAIT_SECTOR && header_fetch && sd_sec_read_data_valid)begin
  case(rx_index)
   0:signature[7:0]<=sd_sec_read_data;1:signature[15:8]<=sd_sec_read_data;
   2:file_len[7:0]<=sd_sec_read_data;3:file_len[15:8]<=sd_sec_read_data;
   4:file_len[23:16]<=sd_sec_read_data;5:file_len[31:24]<=sd_sec_read_data;
   10:pixel_offset[7:0]<=sd_sec_read_data;11:pixel_offset[15:8]<=sd_sec_read_data;
   12:pixel_offset[23:16]<=sd_sec_read_data;13:pixel_offset[31:24]<=sd_sec_read_data;
   14:dib_size[7:0]<=sd_sec_read_data;15:dib_size[15:8]<=sd_sec_read_data;
   16:dib_size[23:16]<=sd_sec_read_data;17:dib_size[31:24]<=sd_sec_read_data;
   18:width[7:0]<=sd_sec_read_data;19:width[15:8]<=sd_sec_read_data;
   20:width[23:16]<=sd_sec_read_data;21:width[31:24]<=sd_sec_read_data;
   22:height[7:0]<=sd_sec_read_data;23:height[15:8]<=sd_sec_read_data;
   24:height[23:16]<=sd_sec_read_data;25:height[31:24]<=sd_sec_read_data;
   26:planes[7:0]<=sd_sec_read_data;27:planes[15:8]<=sd_sec_read_data;
   28:bit_count[7:0]<=sd_sec_read_data;29:bit_count[15:8]<=sd_sec_read_data;
   30:compression[7:0]<=sd_sec_read_data;31:compression[15:8]<=sd_sec_read_data;
   32:compression[23:16]<=sd_sec_read_data;33:compression[31:24]<=sd_sec_read_data;
  endcase
 end
end
always @(posedge clk or posedge rst)begin
 if(rst)begin
  state<=IDLE;fetch_return<=IDLE;rx_index<=0;byte_index<=0;header_fetch<=0;scanning<=0;
  scan_sector<=0;load_base<=0;file_pos<=0;settle<=0;component<=0;bgr<=0;
  row_byte<=0;src_x<=0;src_y<=0;target_y<=0;sample_x<=0;
  fit_w<=640;fit_h<=480;pad_x<=0;pad_y<=0;out_x<=0;out_y<=0;image_y<=0;
  dividend<=0;divisor<=1;quotient<=0;wide_image<=0;image_row<=0;
  pos_at_end<=0;pos_sector<=0;
  x_error<=0;y_error<=0;pace<=0;step_remainder<=0;step_again<=0;
  sd_sec_read<=0;sd_sec_read_addr<=0;write_req<=0;scan_done<=0;
  scan_found_valid<=0;scan_found_sector<=0;scan_found_total<=0;
  bmp_data_wr_en<=0;bmp_data<=0;load_error<=0;bmp_error<=0;state_code<=0;
  ready<=1;
 end else begin
  bmp_data_wr_en<=0;scan_found_valid<=0;load_error<=0;
  // Same cycle as the IDLE exit below; one cycle late when returning to IDLE.
  ready<=state==IDLE && !(sd_init_done && (scan_start || load_start));
  case(state)
   IDLE:begin
    state_code<=1;sd_sec_read<=0;write_req<=0;
    if(sd_init_done && scan_start)begin
     scanning<=1;scan_done<=0;scan_found_total<=0;scan_sector<=scan_start_sector;
     sd_sec_read_addr<=scan_start_sector;header_fetch<=1;fetch_return<=HEADER_SETTLE;state<=FETCH;
    end else if(sd_init_done && load_start)begin
     scanning<=0;bmp_error<=0;load_base<=load_sector;sd_sec_read_addr<=load_sector;
     header_fetch<=1;fetch_return<=HEADER_SETTLE;state<=FETCH;
    end
   end
   FETCH:begin rx_index<=0;sd_sec_read<=1;state<=WAIT_SECTOR;state_code<=2;end
   WAIT_SECTOR:begin
    if(sd_sec_read_data_valid)rx_index<=rx_index+1'b1;
    if(sd_sec_read_end)begin sd_sec_read<=0;byte_index<=0;settle<=3;state<=fetch_return;end
   end
   HEADER_SETTLE:if(settle!=0)settle<=settle-1'b1;else state<=HEADER_CHECK;
   HEADER_CHECK:begin
    if(scanning)begin
     if(header_ok)begin
      scan_found_valid<=1;scan_found_sector<=scan_sector;scan_found_total<=scan_found_total+1'b1;
      if(scan_found_total+1'b1>=scan_target_count || scan_next>scan_max_sector || scan_next<=scan_sector)begin
       scan_done<=1;state<=IDLE;
      end else begin scan_sector<=scan_next;sd_sec_read_addr<=scan_next;state<=FETCH;end
     end else if(scan_sector>=scan_max_sector)begin scan_done<=1;state<=IDLE;end
     else begin scan_sector<=scan_sector+1'b1;sd_sec_read_addr<=scan_sector+1'b1;state<=FETCH;end
    end else if(!header_ok)begin load_error<=1;bmp_error<=8'h31;state<=IDLE;end
    else state<=GEOMETRY;
   end
   GEOMETRY:begin
    wide_image<=width480>=height640;
    dividend<=width480>=height640?height640:width480;
    divisor<=width480>=height640?width[12:0]:height[12:0];
    quotient<=0;state<=DIVIDE;
   end
   DIVIDE:if(dividend>=divisor)begin dividend<=dividend-divisor;quotient<=quotient+1'b1;end
    else begin fit_w<=wide_image?bmp_width[10:0]:(quotient==0?10'd1:quotient);
     fit_h<=wide_image?(quotient==0?10'd1:quotient):bmp_height[10:0];state<=FIT_READY;end
   FIT_READY:begin
    pad_x<=(bmp_width-fit_w)>>1;pad_y<=(bmp_height-fit_h)>>1;
    file_pos<=0;pos_at_end<=file_len==0;pos_sector<=0;row_byte<=0;component<=0;src_x<=0;src_y<=0;target_y<=0;
    out_x<=0;out_y<=0;image_y<=0;x_error<=0;y_error<=0;sample_x<=0;
    write_req<=1;state<=WRITE_ACK;state_code<=3;
   end
   WRITE_ACK:if(ack_sync)begin
    write_req<=0;header_fetch<=0;sd_sec_read_addr<=load_base;fetch_return<=STREAM_ADDR;
    // First header sector is already buffered; consume it after bottom margin.
    byte_index<=0;image_row<=0;
    state<=WRITE_DRAIN;
   end
   // ACK falls only after the SDRAM writer releases its asynchronous FIFO reset.
   WRITE_DRAIN:if(!ack_sync)begin
    if(pad_y!=0)state<=OUT_ADDR;else state<=STREAM_ADDR;
   end
   STREAM_ADDR:begin
    state_code<=4;
    if(pos_at_end)state<=FINISH;
    else if(pos_sector)begin
     sd_sec_read_addr<=sd_sec_read_addr+1'b1;fetch_return<=BUFFER_READY;state<=FETCH;
    end else state<=STREAM_BYTE;
   end
   BUFFER_READY:state<=STREAM_BYTE;
   STREAM_BYTE:begin
    // BRAM read has a full address cycle before this state.
    file_pos<=file_pos+1'b1;byte_index<=byte_index+1'b1;state<=STREAM_ADDR;
    pos_at_end<=file_pos>=file_len_m1;pos_sector<=file_pos[8:0]==9'd511;
    if(stream_pixel)begin
     row_byte<=row_byte+1'b1;
     if(stream_payload)begin
      case(component)
       0:begin bgr[7:0]<=byte_q;component<=1;end
       1:begin bgr[15:8]<=byte_q;component<=2;end
       2:begin component<=0;src_x<=src_x+1'b1;end
      endcase
     end
     if(stream_row_end)begin row_byte<=0;component<=0;src_x<=0;state<=ROW_DONE;end
    end
   end
   ROW_DONE:begin
    src_y<=src_y+1'b1;
    if(row_hit)begin
     image_row<=1;out_x<=0;sample_x<=0;x_error<=0;state<=OUT_ADDR;
    end else state<=STREAM_ADDR;
   end
   OUT_ADDR:state<=OUT_PIXEL;
   OUT_PIXEL:begin
    bmp_data<=out_inside?row_q:24'd0;
    bmp_data_wr_en<=1;pace<=63;state<=OUT_PACE;
   end
   OUT_PACE:if(pace!=0)pace<=pace-1'b1;
    else if(out_last)begin out_x<=0;out_y<=out_y+1'b1;
     if(image_row)begin image_y<=image_y+1'b1;y_error<=y_error+height[12:0];state<=Y_STEP;end
     else state<=ROW_EVAL;
    end else begin
     out_x<=out_x+1'b1;
     if(out_inside)begin x_error<=x_error+width[12:0];state<=X_STEP;end
     else state<=OUT_ADDR;
    end
   // Separate comparison/subtraction from the conditional counter update.
   X_STEP:begin
    step_remainder<=x_error-fit_w;step_again<=x_error>=fit_w;state<=X_APPLY;
   end
   X_APPLY:if(step_again)begin
    x_error<=step_remainder;sample_x<=sample_x+1'b1;state<=X_STEP;
   end else state<=OUT_ADDR;
   Y_STEP:begin
    step_remainder<=y_error-fit_h;step_again<=y_error>=fit_h;state<=Y_APPLY;
   end
   Y_APPLY:if(step_again)begin
    y_error<=step_remainder;target_y<=target_y+1'b1;state<=Y_STEP;
   end else state<=ROW_EVAL;
   ROW_EVAL:state<=ROW_NEXT;
   ROW_NEXT:begin
    if(row_past_end)begin image_row<=0;state<=STREAM_ADDR;end
    else if(row_margin)begin image_row<=0;state<=OUT_ADDR;end
    else if(row_repeat)begin sample_x<=0;x_error<=0;state<=OUT_ADDR;end
    else state<=STREAM_ADDR;
   end
   FINISH:begin
    if(out_y!=bmp_height || src_y!=height)begin load_error<=1;bmp_error<=8'h37;end
    state<=IDLE;
   end
   default:state<=IDLE;
  endcase
 end
end
endmodule
