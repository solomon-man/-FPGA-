`timescale 1ns/1ps
module tb_memory_addresses;
reg clk=0;always #10 clk=~clk;
reg rst=1,req=0;reg [1:0] index=0;
wire we,ack,finished;
wire [20:0] address;
frame_fifo_write #(.BURST_BITS(9),.BURST_SIZE(256),.WRITE_V_FLIP(1),
 .FRAME_WIDTH(640),.FRAME_HEIGHT(480)) dut(
 .rst(rst),.mem_clk(clk),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),
 .Sdr_busy(1'b0),.App_rd_busy(1'b0),.O_wr_busy(),.App_wr_en(we),.App_wr_addr(address),
 .write_req(req),.write_req_ack(ack),.write_finish(finished),
 .write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd614400),
 .write_addr_3(21'd921600),.write_addr_index(index),.write_len(21'd307200),
 .fifo_aclr(),.rdusedw(10'd511));
integer count=0,n,expected;
always @(posedge clk) begin
 if(!rst && we) begin
  expected=index*307200+(479-count/640)*640+count%640;
  if(address!==expected[20:0]) $fatal(1,"Bank/VFLIP address mismatch index=%d pixel=%d got=%d expected=%d",index,count,address,expected);
  count=count+1;
 end
end
initial begin
 repeat(4) @(negedge clk);rst=0;
 for(n=0;n<4;n=n+1) begin
  index=n;count=0;req=1;
  wait(ack);@(negedge clk);req=0;
  wait(finished);@(negedge clk);
  if(count!=307200) $fatal(1,"Write completed without full pixel count");
  repeat(8) @(negedge clk);
 end
 $display("ALL_FOUR_BANK_FULL_FRAME_VFLIP_ADDRESS_PASS");$finish;
end
initial begin #30000000;$fatal(1,"Memory address test timeout");end
endmodule
