`timescale 1ns/1ps
`include "global_def.v"
module tb_sdram_refresh;
reg clk=0, rst=1;
always #6 clk=~clk;
wire done, refresh_req;
integer count=0, first_cycle=-1, previous_cycle=-1, pulses=0;
sdr_init_ref dut(.Sdr_clk(clk), .Rst(rst), .Sdr_init_req(1'b0),
 .Sdr_init_mode(4'b0000), .Sdr_init_done(done), .App_ref_req(1'b0),
 .Sdr_ref_req(refresh_req), .Sdr_ref_ack(refresh_req), .Sdr_rw_vld(1'b0),
 .Sdr_init_ref_vld(), .Sdr_init_ref_ras(), .Sdr_init_ref_cas(),
 .Sdr_init_ref_we(), .Sdr_init_ref_ba(), .Sdr_init_ref_addr());
initial begin
 if(`SDR_CLK_PERIOD!=12 || `SELF_REFRESH_INTERVAL!=2603)
  $fatal(1,"Incorrect SDRAM clock/refresh macro expansion");
 repeat(5) @(negedge clk);
 rst=0;
 wait(done===1);
 while(pulses<3) begin
  @(negedge clk); count=count+1;
  if(refresh_req) begin
   if(previous_cycle>=0 && count-previous_cycle!=2604)
    $fatal(1,"Incorrect refresh period: %d cycles", count-previous_cycle);
   previous_cycle=count;
   pulses=pulses+1;
  end
 end
 $display("SDRAM_REFRESH_PASS: period 12 ns, counter 2603, refresh request interval 2604 cycles");
 $finish;
end
initial begin #3000000; $fatal(1,"SDRAM initialization/refresh timeout"); end
endmodule
