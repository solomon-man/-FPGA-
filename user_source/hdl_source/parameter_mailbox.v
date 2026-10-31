// Bundled-data CDC with round-trip acknowledgement. The bus stays stable
// until the pixel domain consumes it at a frame boundary.
module parameter_mailbox #(parameter [46:0] DEFAULT=47'h5000040080,parameter integer WIDTH=47)(
 input source_clk,source_rst,input [WIDTH-1:0] source_data,
 input clk,rst,frame_start,output reg [WIDTH-1:0] data);
reg [WIDTH-1:0] mailbox;
reg request,ack;
reg [2:0] ack_sync,request_sync;
always @(posedge source_clk or posedge source_rst) begin
 if(source_rst) begin mailbox<=DEFAULT;request<=0;ack_sync<=0;end
 else begin
  ack_sync<={ack_sync[1:0],ack};
  if(ack_sync[2]==request && source_data!=mailbox) begin
   mailbox<=source_data;request<=~request;
  end
 end
end
always @(posedge clk or posedge rst) begin
 if(rst) begin data<=DEFAULT;ack<=0;request_sync<=0;end
 else begin
  request_sync<={request_sync[1:0],request};
  if(frame_start && request_sync[2]!=ack) begin data<=mailbox;ack<=request_sync[2];end
 end
end
endmodule
