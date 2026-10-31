// Compatibility name: source scaling now occurs in SDRAM address generation.
// Preserve original one-cycle video latency and mask centered borders.
module thumbnail_scaler #(parameter SOURCE_SCALED=0)(input clk,rst,frame_start,de,input [1:0] image_bank,
 input [9:0] x,y,input [23:0] rgb,input [4:0] scale,
 output reg [23:0] scaled,output reg out_de,output ready);
wire [10:0] half_width=scale*11'd32;
wire [9:0] half_height=scale*10'd24;
wire visible=SOURCE_SCALED || scale>=10 || (x>=320-half_width && x<320+half_width &&
                          y>=240-half_height && y<240+half_height);
assign ready=1'b1;
always @(posedge clk or posedge rst)begin
 if(rst)begin scaled<=0;out_de<=0;end
 else begin scaled<=de && visible?rgb:24'd0;out_de<=de;end
end
endmodule
