// UNVERIFIED OLD PROTOTYPE. Not integrated; not safe for real display ownership.
// Four 32-bit-per-pixel VGA preview banks are retained while one XGA bank is
// filled in the background.  A completed XGA frame is advertised only at a
// frame boundary; a cancelled request can never overwrite the displayed bank.
module preview_xga_manager #(
    parameter ADDR_BITS=21,
    parameter PREVIEW_STRIDE=640,       // words/row, one RGB888 pixel in each 32-bit word
    parameter PREVIEW_ROWS=480,
    parameter XGA_BASE=21'd1228800,
    parameter XGA_STRIDE=1024,
    parameter XGA_ROWS=768
)(
    input clk,input rst,input request,input [3:0] request_photo,
    input preview_ready,input xga_word_valid,input xga_word_last,
    output reg load_active,output reg [3:0] load_photo,
    output reg xga_write_valid,output reg [ADDR_BITS-1:0] xga_write_addr,
    output reg preview_visible,output reg hd_visible,
    output reg [3:0] visible_photo,output reg [ADDR_BITS-1:0] visible_base,
    output reg commit_toggle,output reg load_cancelled
);
 localparam XGA_WORDS=XGA_STRIDE*XGA_ROWS;
 reg [31:0] count; reg [3:0] pending_photo;
 always @(posedge clk or posedge rst) begin
   if(rst) begin load_active<=0;load_photo<=0;pending_photo<=0;count<=0;
     xga_write_valid<=0;xga_write_addr<=XGA_BASE;preview_visible<=0;hd_visible<=0;
     visible_photo<=0;visible_base<=0;commit_toggle<=0;load_cancelled<=0;
   end else begin
     xga_write_valid<=0;load_cancelled<=0;
     if(request && (!load_active || request_photo!=pending_photo)) begin
       if(load_active) load_cancelled<=1;
       pending_photo<=request_photo; load_photo<=request_photo; load_active<=1;
       count<=0; xga_write_addr<=XGA_BASE;
       preview_visible<=preview_ready; hd_visible<=0;
       visible_photo<=request_photo; visible_base<=0;
     end
     if(load_active && xga_word_valid) begin
       xga_write_valid<=1; xga_write_addr<=XGA_BASE+count;
       if(count+1>=XGA_WORDS || xga_word_last) begin
         load_active<=0; hd_visible<=1; preview_visible<=0;
         visible_photo<=pending_photo;visible_base<=XGA_BASE;
         commit_toggle<=~commit_toggle; count<=0;
       end else count<=count+1;
     end
   end
 end
endmodule

