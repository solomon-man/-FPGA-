module xga_scale_config(input hd,input [4:0] scale,
 output reg [9:0] sx,sy,output reg [7:0] xp,yp,den,
 output [6:0] inc, output reg [10:0] left_edge,right_edge,top_edge,bottom_edge);
assign inc=hd?7'd80:7'd50;
always @* begin
 sx=0;sy=0;xp=0;yp=0;den=80;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;
 case({hd,scale})
6'd3:begin sx=0;sy=0;xp=0;yp=0;den=24;left_edge=358;right_edge=666;top_edge=269;bottom_edge=499;end
6'd4:begin sx=0;sy=0;xp=0;yp=0;den=32;left_edge=307;right_edge=717;top_edge=230;bottom_edge=538;end
6'd5:begin sx=0;sy=0;xp=0;yp=0;den=40;left_edge=256;right_edge=768;top_edge=192;bottom_edge=576;end
6'd6:begin sx=0;sy=0;xp=0;yp=0;den=48;left_edge=205;right_edge=819;top_edge=154;bottom_edge=614;end
6'd7:begin sx=0;sy=0;xp=0;yp=0;den=56;left_edge=154;right_edge=870;top_edge=115;bottom_edge=653;end
6'd8:begin sx=0;sy=0;xp=0;yp=0;den=64;left_edge=102;right_edge=922;top_edge=77;bottom_edge=691;end
6'd9:begin sx=0;sy=0;xp=0;yp=0;den=72;left_edge=51;right_edge=973;top_edge=38;bottom_edge=730;end
6'd10:begin sx=0;sy=0;xp=0;yp=0;den=80;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd11:begin sx=29;sy=21;xp=8;yp=72;den=88;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd12:begin sx=53;sy=40;xp=32;yp=0;den=96;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd13:begin sx=73;sy=55;xp=88;yp=40;den=104;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd14:begin sx=91;sy=68;xp=48;yp=64;den=112;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd15:begin sx=106;sy=80;xp=80;yp=0;den=120;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd16:begin sx=120;sy=90;xp=0;yp=0;den=128;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd17:begin sx=131;sy=98;xp=104;yp=112;den=136;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd18:begin sx=142;sy=106;xp=32;yp=96;den=144;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd19:begin sx=151;sy=113;xp=88;yp=104;den=152;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd20:begin sx=160;sy=120;xp=0;yp=0;den=160;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd35:begin sx=0;sy=0;xp=0;yp=0;den=24;left_edge=358;right_edge=666;top_edge=269;bottom_edge=499;end
6'd36:begin sx=0;sy=0;xp=0;yp=0;den=32;left_edge=307;right_edge=717;top_edge=230;bottom_edge=538;end
6'd37:begin sx=0;sy=0;xp=0;yp=0;den=40;left_edge=256;right_edge=768;top_edge=192;bottom_edge=576;end
6'd38:begin sx=0;sy=0;xp=0;yp=0;den=48;left_edge=205;right_edge=819;top_edge=154;bottom_edge=614;end
6'd39:begin sx=0;sy=0;xp=0;yp=0;den=56;left_edge=154;right_edge=870;top_edge=115;bottom_edge=653;end
6'd40:begin sx=0;sy=0;xp=0;yp=0;den=64;left_edge=102;right_edge=922;top_edge=77;bottom_edge=691;end
6'd41:begin sx=0;sy=0;xp=0;yp=0;den=72;left_edge=51;right_edge=973;top_edge=38;bottom_edge=730;end
6'd42:begin sx=0;sy=0;xp=0;yp=0;den=80;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd43:begin sx=46;sy=34;xp=48;yp=80;den=88;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd44:begin sx=85;sy=64;xp=32;yp=0;den=96;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd45:begin sx=118;sy=88;xp=16;yp=64;den=104;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd46:begin sx=146;sy=109;xp=32;yp=80;den=112;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd47:begin sx=170;sy=128;xp=80;yp=0;den=120;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd48:begin sx=192;sy=144;xp=0;yp=0;den=128;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd49:begin sx=210;sy=158;xp=112;yp=16;den=136;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd50:begin sx=227;sy=170;xp=80;yp=96;den=144;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd51:begin sx=242;sy=181;xp=80;yp=136;den=152;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
6'd52:begin sx=256;sy=192;xp=0;yp=0;den=160;left_edge=0;right_edge=1024;top_edge=0;bottom_edge=768;end
endcase
end
endmodule
