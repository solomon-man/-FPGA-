// 16x16 Chinese OSD; glyph rows are stored in inferred block RAM.
module text_layers #(parameter ENABLE_TEMPERATURE=0,PIPELINED_RENDER=0)(input [23:0] rgb,input de,input [9:0] x,y,input [3:0] page,input signed [8:0] brightness,input [8:0] contrast,input [4:0] scale,input [1:0] transition,subtitle,input [3:0] bank,input auto_enabled,input [7:0] error_code,input osd_enable,subtitle_enable,input [9:0] scroll,output reg [23:0] out_rgb,input [2:0] music_track,music_status,input [1:0] visual_mode,speed,input speed_toast,input [1:0] audio_item,input mute,music_enable,click_enable,visual_enable,input signed [6:0] temperature,input clk,rst);
localparam SP=8'hff;
// Indices follow FONTMAP.TXT/FONT16.BIN on the SD card.
localparam ZHONG=128,YUE=129,LIANG=130,WEI=131,XIANG=132,RU=133,QUAN=134,GUAN=135,QIE=136,DONG=137,XIANG2=138,QI=139,TU=140,FU=141,DUI=142,DU=143,KAI=144,XING=145,JING=146,KUAI=147,ZONG=148,MAN=149,AN=150,BO=151,CA=152,FANG=153,XIAO=154,QU=155,SHU=156,ZHU=157,BI=158,BO2=159,CE=160,DAN=161,WEN=162,TE=163,ZHUANG=164,MU=165,ZHI=166,JIE=167,SUO=168,ZI=169,LAN=170,SHI=171,WU=172,PU=173,ZAI=174,SU=175,BU=176,CUO=177,JIAN=178,BI2=179,CHU=180,JING2=181,YIN=182,PIN=183;
(* ram_style="bram" *) reg [15:0] rom[0:1023]; // synthesis force_ram
// Absolute project path: TD and ModelSim use different relative-path bases.
initial $readmemh("G:/ANLU_Project/digital photo frame3.0/user_source/hdl_source/font16_rows.mem",rom);
function [34:0] sf;input [7:0] c;begin case(c)
"0":sf=35'b01110100011001110101110011000101110;"1":sf=35'b00100011000010000100001000010001110;"2":sf=35'b01110100010000100010001000100011111;"3":sf=35'b11110000010000101110000010000111110;"4":sf=35'b00010001100101010010111110001000010;"5":sf=35'b11111100001000011110000010000111110;"6":sf=35'b01110100001000011110100011000101110;"7":sf=35'b11111000010001000100010000100001000;"8":sf=35'b01110100011000101110100011000101110;"9":sf=35'b01110100011000101111000010000101110;"+":sf=35'b00000001000010011111001000010000000;"-":sf=35'b00000000000000011111000000000000000;"%":sf=35'b11001110100010001000101100011000000;":":sf=35'b00000001000010000000001000010000000;default:sf=0;endcase end endfunction
reg panel,sel;reg [7:0] c;reg [5:0] col;reg [3:0] row,lx,ly,item,dig;reg [8:0] num;reg [10:0] t;
always @*begin panel=0;sel=0;c=SP;col=0;row=0;lx=0;ly=0;item=0;dig=0;num=0;t=0;
 if(de&&(page!=0||speed_toast)&&x>=8&&x<(page==6?552:360)&&y>=8&&y<(page==6?(ENABLE_TEMPERATURE?224:208):32))begin
  panel=1;t=x-16;col=t[9:4];lx=t[3:0];t=y-12;row=t[7:4];ly=t[3:0];
  if(page==6)case(row)
   0:case(col)0:c=ZONG;1:c=LAN;4:c=AN;5:c=JIAN;6:c="3";7:c="+";8:c=AN;9:c=JIAN;10:c="4";12:c=QUAN;13:c=BU;14:c=FU;15:c=WEI;endcase
   1:item=4;2:item=5;3:item=3;4:item=2;5:item=1;
   6:begin case(col)0:c=TU;1:c=XIANG;2:c=":";4:c=bank==9?"1":49+bank;5:if(bank==9)c="0";7:c=ZI;8:c=DONG;9:c=":";11:c=48+auto_enabled;endcase end
   7:begin case(col)0:c=CUO;1:c=WU;2:c=":";endcase if(col>=4&&col<=6)begin num=error_code;dig=col==4?num/100:col==5?(num/10)%10:num%10;c=48+dig;end end
   8:item=7;9:item=8;10:item=9;11:item=10;12:if(ENABLE_TEMPERATURE)item=11;
  endcase else if(row==0)begin item=page==7?7+audio_item:page==8?11:page;sel=col<4;end
  case(item)
   1:begin case(col)0:c=SU;1:c=DU;2:c=":";4:c=speed==0?KUAI:speed==2?MAN:ZHONG;5:c=SU;endcase end
   2:begin case(col)0:c=TE;1:c=XIAO;2:c=":";4:c=transition==1?DAN:transition==2?CA:ZHI;5:c=transition==1?RU:transition==2?CHU:QIE;endcase end
   3:begin case(col)0:c=SUO;1:c=FANG;2:c=":";7:c="%";endcase if(col>=4&&col<=6)begin dig=col==4?(scale>=20?2:scale>=10?1:0):col==5?(scale>=20?0:scale>=10?scale-10:scale):0;c=48+dig;end end
   4:begin case(col)0:c=LIANG;1:c=DU;2:c=":";4:c=brightness[8]?"-":"+";endcase num=brightness[8]?-brightness:brightness;if(col>=5&&col<=7)begin dig=col==5?num/100:col==6?(num/10)%10:num%10;c=48+dig;end end
   5:begin case(col)0:c=DUI;1:c=BI;2:c=DU;3:c=":";endcase num=contrast;if(col>=5&&col<=7)begin dig=col==5?num/100:col==6?(num/10)%10:num%10;c=48+dig;end end
   7:case(col)0:c=JING2;1:c=YIN;2:c=":";4:c=mute?KAI:GUAN;5:c=mute?QI:BI2;endcase
   8:begin case(col)0:c=YIN;1:c=YUE;2:c=":";4:c=QU;5:c=MU;6:c=music_track?48+music_track:"0";8:c=!music_enable?GUAN:music_status==4?CUO:music_status==3?JIE:music_status!=2?ZAI:BO;9:c=!music_enable?BI2:music_status==4?WU:music_status==3?SHU:music_status!=2?RU:FANG;endcase end
   9:case(col)0:c=AN;1:c=JIAN;2:c=YIN;3:c=":";5:c=click_enable?KAI:GUAN;6:c=click_enable?QI:BI2;endcase
   10:begin case(col)0:c=PIN;1:c=PU;2:c=":";4:c=visual_mode==1?ZHU:visual_mode==2?JING:visual_mode==3?BO2:GUAN;5:c=visual_mode==1?ZHUANG:visual_mode==2?XIANG2:visual_mode==3?XING:BI2;endcase end
   11:begin case(col)0:c=WEN;1:c=DU;2:c=":";4:c=temperature[6]?"-":"+";endcase num=temperature[6]?-$signed(temperature):$signed(temperature);if(col>=5&&col<=7)begin dig=col==5?num/100:col==6?(num/10)%10:num%10;c=48+dig;end end
  endcase if(x<16||y<12)begin c=SP;lx=0;sel=0;end
 end end
generate
 if(PIPELINED_RENDER==0)begin:gen_reference_render
  reg ink_ref;reg [15:0] font_row_ref;reg [34:0] small_ref;
  always @*begin
   font_row_ref=0;small_ref=sf(c);ink_ref=0;
   if(c>=128&&c<184)begin font_row_ref=rom[{c[5:0],ly}];ink_ref=font_row_ref[15-lx];end
   else if(c!=SP&&lx>=3&&lx<13&&ly<14)ink_ref=small_ref[34-(ly>>1)*5-((lx-3)>>1)];
   out_rgb=rgb;
   if(panel)out_rgb={2'b0,rgb[23:18],2'b0,rgb[15:10],2'b0,rgb[7:2]};
   if(panel&&ink_ref)out_rgb=sel?24'hffff00:24'hffffff;
  end
 end else begin:gen_bram_render
  reg [7:0] c0,c1;reg [3:0] x0,y0,x1,y1;reg p0,p1,s0,s1;
  reg [15:0] fr1;reg [34:0] sy1;reg [23:0] r0,r1;reg ink;
  // A BRAM read register has no asynchronous reset; p1 masks startup data.
  always @(posedge clk)fr1<=rom[{c0[5:0],y0}];
  always @*begin ink=0;if(c1>=128&&c1<184)ink=fr1[15-x1];else if(c1!=SP&&x1>=3&&x1<13&&y1<14)ink=sy1[34-(y1>>1)*5-((x1-3)>>1)];end
  always @(posedge clk or posedge rst)begin
   if(rst)begin c0<=SP;c1<=SP;x0<=0;y0<=0;x1<=0;y1<=0;p0<=0;p1<=0;s0<=0;s1<=0;sy1<=0;r0<=0;r1<=0;out_rgb<=0;end
   else begin c0<=c;x0<=lx;y0<=ly;p0<=panel;s0<=sel;r0<=rgb;sy1<=sf(c0);c1<=c0;x1<=x0;y1<=y0;p1<=p0;s1<=s0;r1<=r0;out_rgb<=r1;if(p1)out_rgb<={2'b0,r1[23:18],2'b0,r1[15:10],2'b0,r1[7:2]};if(p1&&ink)out_rgb<=s1?24'hffff00:24'hffffff;end
  end
 end
endgenerate
endmodule
