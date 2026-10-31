// Two independent row buffers: SDRAM fetch and resampling overlap at 100 MHz.
// The video FIFO crosses to 65 MHz. Frame restart drains the outstanding row
// before acknowledging/resetting the FIFO; no old response enters a new frame.
module scaled_frame_reader #(parameter BANK_BITS=3)(
 input clk,rst,init_done,refresh,sdr_busy,writer_busy,
 output hd_read_busy,output reader_busy,app_en,output [20:0] app_addr,
 input sdr_valid,input [31:0] sdr_data,input read_req,
 output reg read_ack,output read_finish,input [BANK_BITS-1:0] bank,input [4:0] scale,
 input [20:0] base0,base1,base2,base3,base4,base5,input [9:0] fifo_used,
 output reg fifo_clear,output reg pixel_valid,output [31:0] pixel_data);
reg [2:0] req_sync;
reg [BANK_BITS-1:0] bank0,bank1;
reg [4:0] sc0,sc1,sc;
reg hd,running,restarting;
reg [20:0] base,line_address;
reg [1:0] full;
reg fetch_bank,emit_bank;
reg [2:0] fs;
reg [1:0] es;
reg [10:0] fetched,produced,received,out_x;
reg [9:0] sy,sx;
reg [7:0] yp,xp;
reg line_request,line_done;
wire line_ack,line_finish;
wire [9:0] initial_x,initial_y;
wire [7:0] initial_xp,initial_yp,den;
wire [6:0] inc;
wire [10:0] le,re,te,be;
xga_scale_config config_lut(hd,sc,initial_x,initial_y,initial_xp,initial_yp,den,inc,le,re,te,be);
function [10:0] advance;
 input [7:0] phase,denominator;input [6:0] amount;
 reg [9:0] sum,d,d3;
 reg [10:0] delta1,delta2,delta3,delta4;
 begin
 sum={2'b00,phase}+{3'b000,amount};d={2'b00,denominator};d3=(d<<1)+d;
 delta1={1'b0,sum}-{1'b0,d};delta2={1'b0,sum}-{1'b0,(d<<1)};
 delta3={1'b0,sum}-{1'b0,d3};delta4={1'b0,sum}-{1'b0,(d<<2)};
 if(!delta4[10])advance={3'd4,delta4[7:0]};
 else if(!delta3[10])advance={3'd3,delta3[7:0]};
 else if(!delta2[10])advance={3'd2,delta2[7:0]};
 else if(!delta1[10])advance={3'd1,delta1[7:0]};
 else advance={3'd0,sum[7:0]};end
endfunction
wire [10:0] nx=advance(xp,den,inc),ny=advance(yp,den,inc);
wire [9:0] safe_sx=hd?sx:(sx>639?10'd639:sx);
wire [9:0] safe_sy=hd?(sy>767?10'd767:sy):(sy>479?10'd479:sy);
wire emit_pixel=running && !restarting && !req_sync[2] && es==1 && fifo_used<960;
wire visible=out_x>=le && out_x<re && produced>=te && produced<be;
reg [31:0] row0[0:1023]; /* fehdl force_ram=1, ram_style="bram" */
reg [31:0] row1[0:1023]; /* fehdl force_ram=1, ram_style="bram" */
reg [31:0] q0,q1;reg bank_q,vis_q;
assign pixel_data=vis_q?(bank_q?q1:q0):32'd0;
assign hd_read_busy=hd && (fs!=0 || (running && produced<768));
assign read_finish=running && produced==768;
always @(posedge clk)begin
 if(sdr_valid && (fs==1 || fs==2))begin
  if(fetch_bank)row1[received[9:0]]<=sdr_data;else row0[received[9:0]]<=sdr_data;
 end
 q0<=row0[safe_sx];q1<=row1[safe_sx];bank_q<=emit_bank;vis_q<=visible;
end
frame_fifo_read #(.BURST_SIZE(128)) contiguous_reader(
 .rst(rst),.mem_clk(clk),.Sdr_init_done(init_done),.Sdr_init_ref_vld(refresh),.Sdr_busy(sdr_busy),
 .Sdr_rd_en(sdr_valid),.App_wr_busy(writer_busy),.O_rd_busy(reader_busy),
 .App_rd_en(app_en),.App_rd_addr(app_addr),.read_req(line_request),.read_req_ack(line_ack),
 .read_finish(line_finish),.read_addr_0(line_address),.read_addr_1(line_address),
 .read_addr_2(line_address),.read_addr_3(line_address),.read_addr_index(2'd0),
 .read_len(hd?21'd1024:21'd640),.fifo_aclr(),.wrusedw(10'd0));
always @(posedge clk or posedge rst)begin
 if(rst)begin
  req_sync<=0;bank0<=0;bank1<=0;sc0<=10;sc1<=10;sc<=10;hd<=0;base<=0;
  running<=0;restarting<=0;read_ack<=0;fifo_clear<=0;pixel_valid<=0;
  fs<=0;es<=0;full<=0;fetch_bank<=0;emit_bank<=0;fetched<=0;produced<=0;
  sy<=0;sx<=0;yp<=0;xp<=0;received<=0;out_x<=0;line_address<=0;line_request<=0;line_done<=0;
 end else begin
  req_sync<={req_sync[1:0],read_req};bank0<=bank;bank1<=bank0;sc0<=scale;sc1<=sc0;
  pixel_valid<=emit_pixel;
  if(req_sync[2])restarting<=1;
  if(line_finish)line_done<=1;
  if(sdr_valid && (fs==1 || fs==2))received<=received+1'b1;
  // Complete a dispatched row even if a new frame is requested.
  if(fs==1 && line_ack)begin line_request<=0;fs<=2;end
  if(fs==2 && (line_done || line_finish) && received==(hd?1024:640))begin
   full[fetch_bank]<=1;fs<=0;fetch_bank<=~fetch_bank;fetched<=fetched+1'b1;
   if(fetched>=te && fetched<be)begin yp<=ny[7:0];sy<=sy+ny[10:8];end
  end
  if(restarting && fs==0)begin
   read_ack<=1;fifo_clear<=1;running<=0;full<=0;es<=0;
   hd<=bank1==4;sc<=sc1;
   case(bank1)0:base<=base0;1:base<=base1;2:base<=base2;3:base<=base3;default:base<=base4;endcase
   if(!req_sync[2] && read_ack)begin
    read_ack<=0;fifo_clear<=0;restarting<=0;running<=1;
    fetched<=0;produced<=0;fetch_bank<=0;emit_bank<=0;sy<=initial_y;yp<=initial_yp;
    sx<=initial_x;xp<=initial_xp;out_x<=0;
   end
  end else if(running && !restarting && !req_sync[2])begin
   if(fs==0 && fetched<768 && !full[fetch_bank])begin
    received<=0;line_done<=0;
    if(fetched<te || fetched>=be)begin
     full[fetch_bank]<=1;fetch_bank<=~fetch_bank;fetched<=fetched+1'b1;
    end else begin
     line_address<=base+(hd?{safe_sy,10'd0}:safe_sy*21'd640);
     line_request<=1;fs<=1;
    end
   end
   if(es==0 && produced<768 && full[emit_bank])begin
    es<=1;out_x<=0;sx<=initial_x;xp<=initial_xp;
   end
   if(emit_pixel)begin
    if(out_x==1023)begin
     full[emit_bank]<=0;emit_bank<=~emit_bank;produced<=produced+1'b1;es<=0;out_x<=0;
    end else begin
     out_x<=out_x+1'b1;
     if(out_x>=le && out_x<re)begin sx<=sx+nx[10:8];xp<=nx[7:0];end
    end
   end
  end
 end
end
endmodule
