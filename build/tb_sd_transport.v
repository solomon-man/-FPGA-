`timescale 1ns/1ps
module tb_sd_transport;
reg clk=0,rdclk=0;always #5 clk=~clk;always #20 rdclk=~rdclk;
reg rst=1,ar=0,br=0,cv=0,ce=0;reg [31:0] al=10,bl=20;reg [7:0] cd=0;
wire av,ae,bv,be,req,idle,timeout;wire [31:0] lba;wire [7:0] rd;
sd_read_arbiter #(.TIMEOUT_CYCLES(40)) arb(.clk(clk),.rst(rst),.a_req(ar),.a_lba(al),.b_req(br),.b_lba(bl),
 .card_data(cd),.card_valid(cv),.card_end(ce),.data(rd),.a_valid(av),.a_end(ae),.b_valid(bv),.b_end(be),
 .card_req(req),.card_lba(lba),.idle(idle),.timeout(timeout));
reg we=0,re=0;reg [31:0] wd=0;wire full,empty;wire [31:0] data;wire [11:0] wl,rl;
pcm_async_fifo fifo(clk,rst,we,wd,full,wl,rdclk,rst,re,data,empty,rl);
integer produced=0,consumed=0,k;reg fifo_running=0,drain=0;reg [7:0] pace=0;
always @(negedge clk)begin
 we=0;
 if(fifo_running && produced<8000 && !full)begin we=1;wd=32'h12340000+produced;end
end
always @(posedge clk)if(we && !full)produced=produced+1;
always @(negedge rdclk)begin
 pace=pace+1'b1;re=drain && pace[1:0]==0 && !empty;
end
always @(posedge rdclk)if(re && !empty)begin
 if(data!==32'h12340000+consumed)$fatal(1,"FIFO order/wrap %d got%h",consumed,data);
 consumed=consumed+1;
end
task cycle;begin @(negedge clk);end endtask
initial begin
 repeat(4)cycle;rst=0;ar=1;br=1;
 // Both clients continuously pending: audio and image must alternate.
 // A complete sector stays with its owner even when request addresses change.
 for(k=0;k<8;k=k+1)begin
  wait(req);#1;
  if(lba!==(k%2==0?32'd20:32'd10))$fatal(1,"Round-robin/starvation grant %0d",k);
  // Routed data, valid and end are registered: they follow the card by one cycle.
  al=30;bl=40;cv=1;cd=8'h5a^k;@(posedge clk);#1;
  if(av!==(k%2==1) || bv!==(k%2==0))$fatal(1,"Owner data routing");
  if(rd!==(8'h5a^k))$fatal(1,"Registered sector data");
  if(lba!==(k%2==0?32'd20:32'd10))$fatal(1,"Granted address changed");
  repeat(3)cycle;cv=0;al=10;bl=20;ce=1;
  if(k==7)begin ar=0;br=0;end
  cycle;ce=0;#1;
  if(ae!==(k%2==1) || be!==(k%2==0))$fatal(1,"Owner completion routing");
  if(req || idle)$fatal(1,"Missing post-sector drain gap");
 end
 wait(idle);cycle;ar=1;wait(req);cycle;ar=0;
 if(!req || lba!=10)$fatal(1,"Single picture grant");
 wait(timeout);#1;
 if(req || ae || be || av || bv)$fatal(1,"Timeout left transfer active");
 cycle;wait(idle);cycle;br=1;wait(req);cycle;br=0;ce=1;cycle;ce=0;
 $display("SD_ARBITER_ROUND_ROBIN_NO_STARVATION_OWNERSHIP_DRAIN_TIMEOUT_PASS");
 fifo_running=1;wait(full);repeat(20)cycle;
 if(produced!=2047)$fatal(1,"FIFO capacity guard");drain=1;
 wait(consumed==8000);repeat(10)cycle;
 if(!empty || wl!=0)$fatal(1,"FIFO empty accounting");
 rst=1;repeat(5)cycle;rst=0;repeat(8)cycle;
 if(!empty || wl!=0 || rl!=0)$fatal(1,"FIFO reset flush");
 $display("PCM_ASYNC_FIFO_BACKPRESSURE_MULTI_WRAP_EXACT_STEREO_PASS");$finish;
end
initial begin #4000000;$fatal(1,"Transport timeout %d %d",produced,consumed);end
endmodule
