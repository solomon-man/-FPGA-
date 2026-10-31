// Fetch complete RGB888 rows using the original contiguous SDRAM burst reader.
// Then resample from BRAM into the existing asynchronous output FIFO.
module scaled_frame_reader #(parameter BANK_BITS=2)(
 input clk,rst,init_done,refresh,sdr_busy,writer_busy,
 output reader_busy,app_en,output [20:0] app_addr,
 input sdr_valid,input [31:0] sdr_data,input read_req,
 output reg read_ack,output read_finish,input [BANK_BITS-1:0] bank,input [4:0] scale,
 input [20:0] base0,base1,base2,base3,base4,base5,input [9:0] fifo_used,
 output reg fifo_clear,output reg pixel_valid,output [31:0] pixel_data);
localparam IDLE=0,ACK=1,PREP=2,WAIT_ACK=3,FETCH=4,EMIT=5,NEXT=6,FINISH=7;
reg [3:0] state;
reg [2:0] req_sync;
reg [4:0] scale0,scale1,latched_scale;
reg [BANK_BITS-1:0] bank0,bank1;
reg [20:0] base,line_address;
reg line_request,line_done;
wire line_ack,line_finish;
reg [9:0] received,out_x;
reg [8:0] out_y;
wire [18:0] source_row;
wire [9:0] source_x;
wire visible;
wire emit_pixel=state==EMIT && fifo_used<960;
reg [31:0] line_ram[0:1023]; /* fehdl force_ram=1, ram_style="bram" */
reg [31:0] read_pixel;reg visible_q;
assign pixel_data=visible_q?read_pixel:32'd0;
source_scale_address address(.clk(clk),.rst(rst),.start(state==ACK),.step(emit_pixel),
 .scale_in(latched_scale),.offset(),.source_row(source_row),.source_x(source_x),.visible(visible));
frame_fifo_read #(.BURST_SIZE(128)) contiguous_reader(
 .rst(rst),.mem_clk(clk),.Sdr_init_done(init_done),.Sdr_init_ref_vld(refresh),.Sdr_busy(sdr_busy),
 .Sdr_rd_en(sdr_valid),.App_wr_busy(writer_busy),.O_rd_busy(reader_busy),
 .App_rd_en(app_en),.App_rd_addr(app_addr),.read_req(line_request),.read_req_ack(line_ack),
 .read_finish(line_finish),.read_addr_0(line_address),.read_addr_1(line_address),
 .read_addr_2(line_address),.read_addr_3(line_address),.read_addr_index(2'd0),
 .read_len(21'd640),.fifo_aclr(),.wrusedw(10'd0));
assign read_finish=state==FINISH;
// No reset on RAM or its output register, to retain block RAM inference.
always @(posedge clk)begin
 if(sdr_valid && (state==WAIT_ACK || state==FETCH) && received<640)
  line_ram[received]<=sdr_data;
 read_pixel<=line_ram[source_x];visible_q<=visible;
end
always @(posedge clk or posedge rst)begin
 if(rst)begin
  req_sync<=0;scale0<=10;scale1<=10;bank0<=0;bank1<=0;latched_scale<=10;
  state<=IDLE;read_ack<=0;fifo_clear<=0;pixel_valid<=0;base<=0;line_address<=0;
  line_request<=0;line_done<=0;received<=0;out_x<=0;out_y<=0;
 end else begin
  req_sync<={req_sync[1:0],read_req};scale0<=scale;scale1<=scale0;bank0<=bank;bank1<=bank0;
  pixel_valid<=emit_pixel;
  if(sdr_valid && (state==WAIT_ACK || state==FETCH))received<=received+1'b1;
  if(line_finish)line_done<=1;
  case(state)
   IDLE:if(req_sync[2] && init_done)state<=ACK;
   ACK:begin
    fifo_clear<=1;read_ack<=1;out_x<=0;out_y<=0;latched_scale<=scale1;
    case(bank1)0:base<=base0;1:base<=base1;2:base<=base2;3:base<=base3;4:base<=base4;5:base<=base5;default:base<=base0;endcase
    if(!req_sync[2])begin fifo_clear<=0;read_ack<=0;state<=PREP;end
   end
   PREP:begin
    if(req_sync[2])state<=ACK;
    else begin
     line_address<=base+source_row;received<=0;line_done<=0;
     if(latched_scale<10 && (out_y<240-latched_scale*24 || out_y>=240+latched_scale*24))state<=EMIT;
     else begin line_request<=1;state<=WAIT_ACK;end
    end
   end
   WAIT_ACK:if(line_ack)begin line_request<=0;state<=FETCH;end
   FETCH:if((line_done || line_finish) && received==640)state<=EMIT;
   EMIT:begin
    if(req_sync[2])state<=ACK;
    else if(emit_pixel)begin
     if(out_x==639)begin out_x<=0;state<=NEXT;end
     else out_x<=out_x+1'b1;
    end
   end
   NEXT:if(out_y==479)state<=FINISH;
    else begin out_y<=out_y+1'b1;state<=PREP;end
   FINISH:state<=IDLE;
   default:state<=IDLE;
  endcase
 end
end
endmodule
