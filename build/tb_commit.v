`timescale 1ns/1ps
module tb_commit;
reg pixel_clk=0,sd_clk=0;
always #20 pixel_clk=~pixel_clk;always #5 sd_clk=~sd_clk;
reg rst=1,req=0,valid=0;reg [1:0] wanted=0;
wire [1:0] active;wire active_valid,mem_req,start;
frame_commit dut(.clk(pixel_clk),.rst(rst),.source_clk(sd_clk),.source_rst(rst),
 .frame_req(req),.requested_bank(wanted),.requested_valid(valid),
 .active_bank(active),.active_valid(active_valid),.memory_req(mem_req),.frame_start(start));
wire reset_out;
reset_release rr(pixel_clk,rst,reset_out);
reg key1=1,key2=1;wire [2:0] mode;
feature_keys #(.HOLD_CYCLES(8)) keys(sd_clk,rst,key1,key2,mode);
integer n;
initial begin
 repeat(3) @(negedge pixel_clk);rst=0;
 if(reset_out!==1) $fatal(1,"Reset released asynchronously");
 repeat(3) @(posedge pixel_clk);#1;
 if(reset_out!==0) $fatal(1,"Reset release delay wrong");
 wanted=2;valid=1;repeat(8) @(negedge pixel_clk);
 if(active_valid!==0 || active!==0) $fatal(1,"Commit occurred in active frame");
 req=1;
 @(posedge pixel_clk);#1;
 if(active!==2 || active_valid!==1 || mem_req!==0) $fatal(1,"Bank and request order wrong");
 @(posedge pixel_clk);#1;
 if(mem_req!==1) $fatal(1,"Memory request missing");
 wanted=3;repeat(8) @(negedge pixel_clk);
 if(active!==2) $fatal(1,"Bank changed while request was held");
 req=0;repeat(4) @(negedge pixel_clk);req=1;
 @(posedge pixel_clk);#1;if(active!==3) $fatal(1,"Next-frame commit failed");
 for(n=1;n<=5;n=n+1) begin
  @(negedge sd_clk);key1=0;key2=0;repeat(16) @(negedge sd_clk);
  if(mode!==(n%5)) $fatal(1,"Preset cycle failed");
  repeat(16) @(negedge sd_clk);if(mode!==(n%5)) $fatal(1,"Held keys repeated");
  key1=1;key2=1;repeat(6) @(negedge sd_clk);
 end
 #3;rst=1;#1;if(reset_out!==1) $fatal(1,"Reset assertion was not immediate");
 $display("FRAME_COMMIT_RESET_KEYS_PASS");$finish;
end
initial begin #100000;$fatal(1,"Commit test timeout");end
endmodule
