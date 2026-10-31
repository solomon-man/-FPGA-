module runtime_adjust #(parameter ENABLE_TEMPERATURE=0)(input [23:0] rgb,input signed [8:0] brightness,
 input [8:0] contrast,output [23:0] adjusted,input signed [6:0] temperature);
function [7:0] channel;
 input [7:0] value;
 input signed [7:0] offset;
 reg signed [9:0] centered;
 reg signed [19:0] product;
 reg signed [20:0] result_value;
 begin
  centered=$signed({1'b0,value})-10'sd128;
  product=centered*$signed({1'b0,contrast});
  result_value=(product>>>7)+21'sd128+brightness+offset;
  channel=result_value<0?8'd0:result_value>255?8'd255:result_value[7:0];
 end
endfunction
wire signed [7:0] warmth=ENABLE_TEMPERATURE?{temperature[6],temperature}:8'sd0;
assign adjusted={channel(rgb[23:16],warmth),channel(rgb[15:8],8'sd0),channel(rgb[7:0],-warmth)};
endmodule

// Three clocks, exact signed contrast/brightness/temperature and saturation.
module runtime_adjust_pipeline(input clk,rst,input [23:0] rgb,
 input signed [8:0] brightness,input [8:0] contrast,input signed [6:0] temperature,
 output reg [23:0] adjusted);
reg signed [19:0] pr,pg,pb;
reg signed [8:0] br;reg signed [7:0] temp;
reg signed [11:0] sr,sg,sb;
wire signed [9:0] cr=$signed({1'b0,rgb[23:16]})-10'sd128;
wire signed [9:0] cg=$signed({1'b0,rgb[15:8]})-10'sd128;
wire signed [9:0] cb=$signed({1'b0,rgb[7:0]})-10'sd128;
function [7:0] clamp;
 input signed [11:0] value;
 begin clamp=value<0?8'd0:value>255?8'd255:value[7:0];end
endfunction
always @(posedge clk or posedge rst)begin
 if(rst)begin pr<=0;pg<=0;pb<=0;br<=0;temp<=0;sr<=0;sg<=0;sb<=0;adjusted<=0;end
 else begin
  pr<=cr*$signed({1'b0,contrast});pg<=cg*$signed({1'b0,contrast});pb<=cb*$signed({1'b0,contrast});
  br<=brightness;temp<={temperature[6],temperature};
  sr<=(pr>>>7)+12'sd128+br+temp;
  sg<=(pg>>>7)+12'sd128+br;
  sb<=(pb>>>7)+12'sd128+br-temp;
  adjusted<={clamp(sr),clamp(sg),clamp(sb)};
 end
end
endmodule
