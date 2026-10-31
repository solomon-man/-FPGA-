`timescale 1ns/1ps
module tb_reader_owner;
reg clk=0;always #6 clk=~clk;
reg rst=1,req=0;reg [2:0] bank=4;
wire ack,en,pv;wire [20:0] addr;wire [31:0] pd;wire [6:0] owned;
reg [7:0] vp=0;reg [20:0] ap[0:7];integer i,n;
scaled_frame_reader dut(.clk(clk),.rst(rst),.init_done(1'b1),.refresh(1'b0),.sdr_busy(1'b0),
 .writer_busy(1'b0),.reader_busy(),.app_en(en),.app_addr(addr),.sdr_valid(vp[7]),
 .sdr_data({ap[7],11'h123}),.read_req(req),.read_ack(ack),.read_finish(),.bank(bank),.scale(5'd10),
 .base0(21'd0),.base1(21'd307200),.base2(21'd614400),.base3(21'd921600),.base4(21'd1228800),.base5(21'd0),
 .fifo_used(10'd0),.fifo_clear(),.pixel_valid(pv),.pixel_data(pd),.hd_read_busy(),.reader_owned(owned));
always @(posedge clk)begin
 vp<={vp[6:0],en};ap[0]<=addr;for(i=1;i<8;i=i+1)ap[i]<=ap[i-1];
end
task move;input [2:0] target;input integer old;
begin
 wait(dut.fs==2 && dut.received>20 && dut.received<100);
 @(negedge clk);bank=target;req=1;
 while(!ack)begin
  @(negedge clk);
  if(dut.fs!=0 && owned!==(7'b1<<old))$fatal(1,"ownership moved before row drain");
 end
 if(vp!=0)$fatal(1,"ack before outstanding memory responses drained");
 @(negedge clk);req=0;wait(!ack);
 if(owned!==(7'b1<<target))$fatal(1,"new ownership not acquired");
 wait(pv);@(negedge clk);
end endtask
initial begin
 repeat(5)@(negedge clk);rst=0;req=1;
 wait(ack);@(negedge clk);req=0;wait(!ack);
 if(owned!==7'b0010000)$fatal(1,"HD4 owner");
 move(5,4);move(6,5);move(0,6);
 $display("SDRAM_READER_OWNER_HD4_HD5_TRANSIENT_VGA_ROW_DRAIN_PASS");$finish;
end
initial begin #2000000;$fatal(1,"owner timeout");end
endmodule
