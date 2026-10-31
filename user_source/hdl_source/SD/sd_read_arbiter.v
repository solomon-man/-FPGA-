// Transaction-level sharing: a granted 512-byte transfer is never preempted.
// Routed data, valid and end are registered together; the five-cycle gap
// covers the one-cycle later end seen by the requester.
module sd_read_arbiter #(parameter TIMEOUT_CYCLES=200_000_000)(
 input clk,rst,input a_req,input [31:0] a_lba,input b_req,input [31:0] b_lba,
 input [7:0] card_data,input card_valid,card_end,output reg [7:0] data,
 output reg a_valid,a_end,b_valid,b_end,
 output reg card_req,output reg [31:0] card_lba,output idle,output reg timeout);
reg owner;reg [2:0] gap;reg [27:0] watchdog;
assign idle=!card_req && gap==0;
always @(posedge clk or posedge rst)begin
 if(rst)begin owner<=0;gap<=0;watchdog<=0;card_req<=0;card_lba<=0;timeout<=0;
  data<=0;a_valid<=0;a_end<=0;b_valid<=0;b_end<=0;end
 else begin
  timeout<=0;data<=card_data;
  a_valid<=card_req && !owner && card_valid;
  b_valid<=card_req && owner && card_valid;
  a_end<=card_req && !owner && card_end;
  b_end<=card_req && owner && card_end;
  if(card_req)begin
   watchdog<=watchdog+1'b1;
   if(card_end)begin card_req<=0;gap<=5;watchdog<=0;end
   else if(watchdog==TIMEOUT_CYCLES-1)begin card_req<=0;gap<=5;watchdog<=0;timeout<=1;end
  end else if(gap!=0)gap<=gap-1'b1;
  else if(a_req || b_req)begin
   owner<=b_req && (!a_req || !owner);card_lba<=(b_req && (!a_req || !owner))?b_lba:a_lba;card_req<=1;watchdog<=0;
  end
 end
end
endmodule
