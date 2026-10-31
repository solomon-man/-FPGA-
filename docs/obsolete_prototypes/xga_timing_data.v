// VESA 1024x768@60 timing. Pixel clock is supplied by the board PLL.
module xga_timing_data(input clk,input rst,output reg hs,vs,de,
 output reg frame_pulse,output reg [10:0] x,output reg [10:0] y);
 localparam HA=1024,HFP=24,HS=136,HBP=160,VA=768,VFP=3,VS=6,VBP=29;
 localparam HT=HA+HFP+HS+HBP,VT=VA+VFP+VS+VBP;
 reg [11:0] hc;reg [10:0] vc;
 always @(posedge clk or posedge rst) if(rst) begin hc<=0;vc<=0;hs<=1;vs<=1;de<=0;x<=0;y<=0;frame_pulse<=0;end else begin
   frame_pulse<=hc==0 && vc==0; de<=hc<HA && vc<VA; x<=hc[10:0];y<=vc;
   hs<=!(hc>=HA+HFP && hc<HA+HFP+HS); vs<=!(vc>=VA+VFP && vc<VA+VFP+VS);
   if(hc==HT-1)begin hc<=0;if(vc==VT-1)vc<=0;else vc<=vc+1;end else hc<=hc+1;
 end
endmodule
