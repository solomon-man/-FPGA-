// Dual-clock PCM FIFO. Gray pointers cross only through two-flop synchronizers.
// Registered RAM read continuously prefetches the next sample before audio_tick.
module pcm_async_fifo #(parameter ADDRESS_BITS=11)(
 input wr_clk,wr_rst,wr_en,input [31:0] wr_data,output wr_full,
 output [ADDRESS_BITS:0] wr_level,
 input rd_clk,rd_rst,rd_en,output reg [31:0] rd_data,output rd_empty,
 output [ADDRESS_BITS:0] rd_level);
localparam W=ADDRESS_BITS+1;
reg [31:0] mem[0:(1<<ADDRESS_BITS)-1];
reg [W-1:0] wb,wg,rb,rg,rm,rs,wm,ws;
// Binary copy of the synchronized read pointer; a stale level only reads high.
reg [W-1:0] rs_bin;
// Next write pointer and its Gray code are registered (3.0 timing), so the
// full flag is a single register compare instead of increment+Gray+compare.
reg [W-1:0] wn,wng;
wire [W-1:0] wn2=wn+1'b1;
function [W-1:0] ungray;input [W-1:0] g;integer k;begin
 ungray[W-1]=g[W-1];for(k=W-2;k>=0;k=k-1)ungray[k]=ungray[k+1]^g[k];
end endfunction
// Leave one slot unused, avoiding overflow even with a stale read pointer.
assign wr_full=wng=={~rs[W-1:W-2],rs[W-3:0]};
assign rd_empty=rg==ws;
assign wr_level=wb-rs_bin;
assign rd_level=ungray(ws)-rb;
always @(posedge wr_clk)if(wr_en && !wr_full)mem[wb[ADDRESS_BITS-1:0]]<=wr_data;
always @(posedge rd_clk)rd_data<=mem[rb[ADDRESS_BITS-1:0]];
always @(posedge wr_clk or posedge wr_rst)begin
 if(wr_rst)begin wb<=0;wg<=0;wn<=1;wng<=1;rm<=0;rs<=0;rs_bin<=0;end
 else begin
  rm<=rg;rs<=rm;rs_bin<=ungray(rs);
  if(wr_en && !wr_full)begin wb<=wn;wg<=wng;wn<=wn2;wng<=(wn2>>1)^wn2;end
 end
end
always @(posedge rd_clk or posedge rd_rst)begin
 if(rd_rst)begin rb<=0;rg<=0;wm<=0;ws<=0;end
 else begin
  wm<=wg;ws<=wm;
  if(rd_en && !rd_empty)begin rb<=rb+1'b1;rg<=((rb+1'b1)>>1)^(rb+1'b1);end
 end
end
endmodule
