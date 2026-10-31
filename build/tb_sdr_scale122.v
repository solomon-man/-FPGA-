`timescale 1ns/1ps
module tb_sdr_scale122;
reg clk=0;always #10 clk=~clk;
wire shifted;assign #8 shifted=clk;
reg rst=1,req=0;reg [4:0] sc=10;reg [1:0] bank=0;
wire init,refresh,sbusy,ack,done,en,clear,busy,rd,pv;wire [31:0] pd;
wire [20:0] addr;wire [31:0] dout;wire mclk,ras,cas,we;wire [1:0] ba;wire [10:0] ma;wire [3:0] dm;wire [31:0] dq;
reg [9:0] used=0;reg wrbusy=0;
reg [20:0] requests[0:2047];integer wp=0,rp=0,returned=0,total=0,m,produced=0,consumed=0;
function [31:0] pattern;input integer a;begin pattern={a[7:0],a[15:8],a[7:0]^a[18:11],8'h00};end endfunction
wire [31:0] memory_data=pattern(requests[returned%2048]);
scaled_frame_reader reader(.clk(clk),.rst(rst),.init_done(init),.refresh(refresh),.sdr_busy(sbusy),
 .writer_busy(wrbusy),.reader_busy(busy),.app_en(en),.app_addr(addr),.sdr_valid(rd),.sdr_data(memory_data),
 .read_req(req),.read_ack(ack),.read_finish(done),.bank(bank),.scale(sc),
 .base0(21'd0),.base1(21'd307200),.base2(21'd614400),.base3(21'd921600),
 .fifo_used(used),.fifo_clear(clear),.pixel_valid(pv),.pixel_data(pd));
sdr_as_ram memory(.Sdr_clk(clk),.Sdr_clk_sft(shifted),.Rst(rst),.Sdr_init_done(init),
 .Sdr_init_ref_vld(refresh),.Sdr_busy(sbusy),.App_ref_req(1'b0),
 .App_wr_en(1'b0),.App_wr_addr(21'd0),.App_wr_dm(4'd0),.App_wr_din(32'd0),
 .App_rd_en(en),.App_rd_addr(addr),.Sdr_rd_en(rd),.Sdr_rd_dout(dout),
 .SDRAM_CLK(mclk),.SDR_RAS(ras),.SDR_CAS(cas),.SDR_WE(we),.SDR_BA(ba),.SDR_ADDR(ma),.SDR_DM(dm),.SDR_DQ(dq));
reg [10:0] rows[0:3];reg [3:0] opened=0;
integer j,cycles=0,active_cycle=-1,xx,yy,sx,sy,expected,level;
reg running=0,consume;
reg [31:0] wanted;
always @(posedge clk)begin
 cycles=cycles+1;
 if(en)begin requests[wp%2048]=addr;wp=wp+1;end
 if(rd)begin
  if(returned>=wp)$fatal(1,"Unexpected SDR data");
  returned<=returned+1;
 end
 consume=running && active_cycle>=0 && active_cycle%2==0 && (active_cycle/2)%800<640 && active_cycle<800*480*2;
 if(running && active_cycle>=0)active_cycle=active_cycle+1;
 if(clear)used=0;
 else begin
  level=used;
  if(consume)begin
   if(level==0)$fatal(1,"Output FIFO underrun scale%0d pixel%0d",m,consumed);
   consumed=consumed+1;level=level-1;
  end
  if(pv)begin
   if(level>=1024)$fatal(1,"Output FIFO overflow");level=level+1;
   xx=produced%640;yy=produced/640;
   sx=((xx-320+32*m)*10)/m;sy=((yy-240+24*m)*10)/m;
   expected=(m%4)*307200+sy*640+sx;wanted=pattern(expected);
   if(m<10 && (xx<320-32*m || xx>=320+32*m || yy<240-24*m || yy>=240+24*m))wanted=0;
   if(pd!==wanted || produced>=307200)$fatal(1,"RGB source mismatch scale%0d pixel%0d expected%h actual%h",m,produced,wanted,pd);
   produced=produced+1;
  end
  used=level;
 end
end
always @(negedge clk)wrbusy=cycles%5000<300;
always @(posedge mclk)begin
 if({ras,cas,we}===3'b011)begin rows[ba]=ma;opened[ba]=1;end
 if({ras,cas,we}===3'b101)begin
  // Controller swizzles four-word bursts across four SDRAM banks.
  if(!opened[ba] || rp>=wp || {rows[ba],ma[7:2],ba,ma[1:0]}!==requests[rp%2048])
   $fatal(1,"Physical SDR READ mismatch scale%0d n%0d expected%h actual%h",m,rp,requests[rp%2048],{rows[ba],ma[7:2],ba,ma[1:0]});
  for(j=1;j<4;j=j+1)if(requests[(rp+j)%2048]!==requests[rp%2048]+j)$fatal(1,"Noncontiguous burst");
  rp=rp+4;total=total+4;
 end
 if({ras,cas,we}===3'b010)begin if(ma[10])opened=0;else opened[ba]=0;end
end
initial begin
 repeat(5)@(negedge clk);rst=0;wait(init);
 for(m=3;m<=20;m=m+1)begin
  @(negedge clk);sc=m;bank=m%4;req=1;wp=0;rp=0;returned=0;produced=0;consumed=0;active_cycle=-1;
  wait(ack);@(negedge clk);req=0;wait(!ack);
  repeat(10000)@(negedge clk);running=1;active_cycle=0;
  // UI may change in the middle of a frame; latched reader settings must not.
  sc=m==20?3:m+1;
  wait(consumed==307200);@(negedge clk);running=0;active_cycle=-1;
  repeat(20)@(negedge clk);
  if(produced!=307200||returned!=wp||rp!=wp||used!=0)$fatal(1,"Frame completion count %0d %0d %0d %0d",produced,returned,wp,used);
  $display("SCALE %0d FULL_RGB888_25MHZ_FIFO_AND_PHYSICAL_SDR_PASS",m);
 end
 $display("ENCRYPTED_SDRAM_PHYSICAL_COMMAND_EIGHTEEN_SCALES_PASS");$finish;
end
initial begin #600000000;$fatal(1,"SDR test timeout");end
endmodule
