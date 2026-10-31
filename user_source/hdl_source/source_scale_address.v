// Scale is a percentage in units of ten: 3=30%, 10=100%, 20=200%.
// Exact rational DDA; no runtime divider and no cumulative image resampling.
module source_scale_address(input clk,rst,start,step,input [4:0] scale_in,
 output [20:0] offset,output [18:0] source_row,output [9:0] source_x,output visible);
reg [4:0] scale,xp,yp,initial_xp;
reg [9:0] x,y,sx,initial_x,left_edge,right_edge,top_edge,bottom_edge;
reg [18:0] row_base;
wire [4:0] chosen=(scale_in>=3 && scale_in<=20)?scale_in:5'd10;
wire inside_x=x>=left_edge && x<right_edge;
wire inside_y=y>=top_edge && y<bottom_edge;
assign source_row=row_base;assign source_x=sx;assign visible=inside_x && inside_y;
assign offset=visible?({2'd0,row_base}+sx):21'd0;
function [7:0] advance;
 input [4:0] phase,den;
 reg [6:0] sum,d1,d2,d3,d4;
 reg [4:0] rem;
 begin
  sum={2'd0,phase}+7'd10;d1={2'd0,den};d2=d1<<1;d3=d2+d1;d4=d1<<2;
  if(sum>=d4)begin rem=sum-d4;advance={3'd4,rem};end
  else if(sum>=d3)begin rem=sum-d3;advance={3'd3,rem};end
  else if(sum>=d2)begin rem=sum-d2;advance={3'd2,rem};end
  else if(sum>=d1)begin rem=sum-d1;advance={3'd1,rem};end
  else advance={3'd0,sum[4:0]};
 end
endfunction
wire [7:0] next_x=advance(xp,scale),next_y=advance(yp,scale);
reg [18:0] row_increment;
always @*case(next_y[7:5])
 1:row_increment=640;2:row_increment=1280;3:row_increment=1920;4:row_increment=2560;
 default:row_increment=0;
endcase
always @(posedge clk or posedge rst)begin
 if(rst)begin
  scale<=10;x<=0;y<=0;sx<=0;initial_x<=0;initial_xp<=0;row_base<=0;xp<=0;yp<=0;
  left_edge<=0;right_edge<=640;top_edge<=0;bottom_edge<=480;
 end else if(start)begin
  scale<=chosen;x<=0;y<=0;
  if(chosen<10)begin
   left_edge<=320-chosen*32;right_edge<=320+chosen*32;
   top_edge<=240-chosen*24;bottom_edge<=240+chosen*24;
  end else begin left_edge<=0;right_edge<=640;top_edge<=0;bottom_edge<=480;end
  case(chosen)
   11:begin sx<=29;initial_x<=29;xp<=1;initial_xp<=1;row_base<=13440;yp<=9;end
   12:begin sx<=53;initial_x<=53;xp<=4;initial_xp<=4;row_base<=25600;yp<=0;end
   13:begin sx<=73;initial_x<=73;xp<=11;initial_xp<=11;row_base<=35200;yp<=5;end
   14:begin sx<=91;initial_x<=91;xp<=6;initial_xp<=6;row_base<=43520;yp<=8;end
   15:begin sx<=106;initial_x<=106;xp<=10;initial_xp<=10;row_base<=51200;yp<=0;end
   16:begin sx<=120;initial_x<=120;xp<=0;initial_xp<=0;row_base<=57600;yp<=0;end
   17:begin sx<=131;initial_x<=131;xp<=13;initial_xp<=13;row_base<=62720;yp<=14;end
   18:begin sx<=142;initial_x<=142;xp<=4;initial_xp<=4;row_base<=67840;yp<=12;end
   19:begin sx<=151;initial_x<=151;xp<=11;initial_xp<=11;row_base<=72320;yp<=13;end
   20:begin sx<=160;initial_x<=160;xp<=0;initial_xp<=0;row_base<=76800;yp<=0;end
   default:begin sx<=0;initial_x<=0;xp<=0;initial_xp<=0;row_base<=0;yp<=0;end
  endcase
 end else if(step)begin
  if(x==639)begin
   x<=0;y<=y+1'b1;sx<=initial_x;xp<=initial_xp;
   if(inside_y)begin yp<=next_y[4:0];row_base<=row_base+row_increment;end
  end else begin
   x<=x+1'b1;
   if(inside_x)begin xp<=next_x[4:0];sx<=sx+next_x[7:5];end
  end
 end
end
endmodule
