`timescale 1ns/1ps
module tb_xga_reader;
reg clk=0;always #6 clk=~clk;
reg rst=1,req=0;reg [2:0] bank=0;reg [4:0] scale=10;
wire ack,done,clear,pv,en,busy;wire [20:0] addr;wire [31:0] pd;
reg [7:0] valid_pipe=0;reg [20:0] addr_pipe[0:7];
wire rv=valid_pipe[7];wire [31:0] rd={addr_pipe[7],11'h5a5};
reg [9:0] used=0;integer i,level,total,consumed,m,b,cycles;real time_pixel;
integer xx,yy,sx,sy,le,te,den,inc,expected;reg [31:0] wanted;
reg consuming=0;
scaled_frame_reader dut(.clk(clk),.rst(rst),.init_done(1'b1),.refresh(1'b0),.sdr_busy(1'b0),
 .writer_busy(cycles%5000<160),.reader_busy(busy),.app_en(en),.app_addr(addr),
 .sdr_valid(rv),.sdr_data(rd),.read_req(req),.read_ack(ack),.read_finish(done),.bank(bank),.scale(scale),
 .base0(21'd0),.base1(21'd307200),.base2(21'd614400),.base3(21'd921600),.base4(21'd1228800),.base5(21'd0),
 .fifo_used(used),.fifo_clear(clear),.pixel_valid(pv),.pixel_data(pd),.hd_read_busy());
always @(posedge clk)begin
 cycles=cycles+1;valid_pipe<={valid_pipe[6:0],en};addr_pipe[0]<=addr;
 for(i=1;i<8;i=i+1)addr_pipe[i]<=addr_pipe[i-1];
 if(clear)used=0;else begin
 level=used;
 if(consuming && $realtime>=time_pixel && consumed<786432)begin
  if(level<=0)$fatal(1,"underflow bank %d scale %d pixel %d",b,m,consumed);
  level=level-1;consumed=consumed+1;
  time_pixel=time_pixel+1000.0/65.0;
  if(consumed%1024==0)time_pixel=time_pixel+320.0*1000.0/65.0;
 end
 if(pv)begin
  if(level>=1023)$fatal(1,"overflow");level=level+1;
  xx=total%1024;yy=total/1024;le=m<10?(1024-(1024*m/10))/2:0;te=m<10?(768-(768*m/10))/2:0;
  den=m*8;inc=b==4?80:50;
  sx=((b==4?1024:640)*(m>10?m-10:0)*4+(xx-le)*inc)/den;
  sy=((b==4?768:480)*(m>10?m-10:0)*4+(yy-te)*inc)/den;
  if(b!=4 && sx>639)sx=639;if(b!=4 && sy>479)sy=479;
  if(b==4 && sy>767)sy=767;
  expected=b*307200+sy*(b==4?1024:640)+sx;wanted={expected[20:0],11'h5a5};
  if(xx<le || xx>=1024-le || yy<te || yy>=768-te)wanted=0;
  if(pd!==wanted)$fatal(1,"pixel mismatch b%d s%d n%d got%h expected%h",b,m,total,pd,wanted);
  total=total+1;
 end
 used=level;
 end
end
initial begin
 cycles=0;total=0;consumed=0;
 repeat(8)@(negedge clk);rst=0;
 for(b=0;b<=4;b=b+4)for(m=3;m<=20;m=m+1)begin
  @(negedge clk);bank=b;scale=m;req=1;total=0;consumed=0;
  wait(ack);@(negedge clk);req=0;wait(!ack);
  repeat(5000)@(negedge clk);time_pixel=$realtime;consuming=1;
  wait(consumed==786432);@(negedge clk);consuming=0;
  if(total!=786432 || used!=0)$fatal(1,"counts %d %d",total,used);
  $display("XGA_READER bank=%d scale=%d FULL_FRAME_PASS",b,m);
 end
 $display("XGA_READER_36_FRAMES_RGB888_BANDWIDTH_PASS");$finish;
end
initial begin #1000000000;$fatal(1,"timeout");end
endmodule
