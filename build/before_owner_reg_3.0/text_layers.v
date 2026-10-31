// 24x24 SimSun OSD drawn 1:1 in XGA coordinates (no 1.6x pixel repeat).
// Cells start at (24,18); three-clock latency: cell -> glyph ROM -> ink/dim.
module text_layers #(parameter ENABLE_TEMPERATURE=0)(input [23:0] rgb,input de,input [9:0] x,y,input [3:0] page,input signed [8:0] brightness,input [8:0] contrast,input [4:0] scale,input [1:0] transition,subtitle,input [3:0] bank,input auto_enabled,input [7:0] error_code,input osd_enable,subtitle_enable,input [9:0] scroll,output reg [23:0] out_rgb,input [2:0] music_track,music_status,input [1:0] visual_mode,speed,input speed_toast,input [1:0] audio_item,input mute,music_enable,click_enable,visual_enable,input signed [6:0] temperature,input clk,rst);
// c is the font ROM glyph index (FONTMAP.TXT/FONT24.BIN on the SD card):
// CJK 0..55, half-width "0".."9" 56..65, "+-%:" 66..69, SP = no glyph.
localparam [6:0] SP=127,D0=56,PLUS=66,MINUS=67,PCT=68,COLON=69;
localparam [6:0] ZHONG=0,YUE=1,LIANG=2,WEI=3,XIANG=4,RU=5,QUAN=6,GUAN=7,QIE=8,DONG=9,XIANG2=10,QI=11,TU=12,FU=13,DUI=14,DU=15,KAI=16,XING=17,JING=18,KUAI=19,ZONG=20,MAN=21,AN=22,BO=23,CA=24,FANG=25,XIAO=26,QU=27,SHU=28,ZHU=29,BI=30,BO2=31,CE=32,DAN=33,WEN=34,TE=35,ZHUANG=36,MU=37,ZHI=38,JIE=39,SUO=40,ZI=41,LAN=42,SHI=43,WU=44,PU=45,ZAI=46,SU=47,BU=48,CUO=49,JIAN=50,BI2=51,CHU=52,JING2=53,YIN=54,PIN=55;
// Three-digit decimal {hundreds,tens,ones} of 0..511.
function [11:0] dec3;input [8:0] n;reg [8:0] h,t,o;begin h=n/100;t=n/10%10;o=n%10;dec3={h[3:0],t[3:0],o[3:0]};end endfunction
// Clock 1: panel bounds and 24-pixel cell position (/8 by wiring, then a
// 7-bit /3 and %3); the displayed values' digits are registered alongside,
// so the pixel path never contains a decimal divider.
reg p1,ok1;reg [5:0] col;reg [3:0] row;reg [4:0] lx1,ly;
reg [11:0] bright_d,contrast_d,error_d,temp_d;reg [7:0] scale_d;
wire [9:0] tx=x-10'd24,ty=y-10'd18;
wire panel=de&&(page!=0||speed_toast)&&x>=12&&x<(page==6?864:576)&&y>=12&&y<(page==6?(ENABLE_TEMPERATURE?336:312):48);
always @(posedge clk or posedge rst)begin
 if(rst)begin p1<=0;ok1<=0;col<=0;row<=0;lx1<=0;ly<=0;bright_d<=0;contrast_d<=0;error_d<=0;temp_d<=0;scale_d<=0;end
 else begin
  p1<=panel;ok1<=x>=24&&y>=18;col<=tx[9:3]/3;lx1<={tx[9:3]%3,tx[2:0]};row<=ty[9:3]/3;ly<={ty[9:3]%3,ty[2:0]};
  bright_d<=dec3(brightness[8]?-brightness:brightness);contrast_d<=dec3(contrast);error_d<=dec3(error_code);
  temp_d<=dec3(temperature[6]?-temperature:temperature);
  scale_d<={scale>=20?4'd2:scale>=10?4'd1:4'd0,scale>=20?4'd0:scale>=10?scale[3:0]-4'd10:scale[3:0]};
 end
end
// Clock 2 input: glyph of the registered cell.
reg sel;reg [6:0] c;reg [3:0] item;
function [6:0] digit;input [11:0] d;input [1:0] i;begin digit=D0+(i==0?d[11:8]:i==1?d[7:4]:d[3:0]);end endfunction
always @*begin sel=0;c=SP;item=0;
 if(p1&&ok1)begin
  if(page==6)case(row)
   0:case(col)0:c=ZONG;1:c=LAN;4:c=AN;5:c=JIAN;6:c=D0+3;7:c=PLUS;8:c=AN;9:c=JIAN;10:c=D0+4;12:c=QUAN;13:c=BU;14:c=FU;15:c=WEI;endcase
   1:item=4;2:item=5;3:item=3;4:item=2;5:item=1;
   6:case(col)0:c=TU;1:c=XIANG;2:c=COLON;4:c=bank==9?D0+1:D0+1+bank;5:if(bank==9)c=D0;7:c=ZI;8:c=DONG;9:c=COLON;11:c=D0+auto_enabled;endcase
   7:case(col)0:c=CUO;1:c=WU;2:c=COLON;4,5,6:c=digit(error_d,col-4);endcase
   8:item=7;9:item=8;10:item=9;11:item=10;12:if(ENABLE_TEMPERATURE)item=11;
  endcase else if(row==0)begin item=page==0?1:page==7?7+audio_item:page==8?11:page;sel=col<4;end // page 0: speed toast
  case(item)
   1:case(col)0:c=SU;1:c=DU;2:c=COLON;4:c=speed==0?KUAI:speed==2?MAN:ZHONG;5:c=SU;endcase
   2:case(col)0:c=TE;1:c=XIAO;2:c=COLON;4:c=transition==1?DAN:transition==2?CA:ZHI;5:c=transition==1?RU:transition==2?CHU:QIE;endcase
   3:case(col)0:c=SUO;1:c=FANG;2:c=COLON;4:c=D0+scale_d[7:4];5:c=D0+scale_d[3:0];6:c=D0;7:c=PCT;endcase
   4:case(col)0:c=LIANG;1:c=DU;2:c=COLON;4:c=brightness[8]?MINUS:PLUS;5,6,7:c=digit(bright_d,col-5);endcase
   5:case(col)0:c=DUI;1:c=BI;2:c=DU;3:c=COLON;5,6,7:c=digit(contrast_d,col-5);endcase
   7:case(col)0:c=JING2;1:c=YIN;2:c=COLON;4:c=mute?KAI:GUAN;5:c=mute?QI:BI2;endcase
   8:case(col)0:c=YIN;1:c=YUE;2:c=COLON;4:c=QU;5:c=MU;6:c=D0+music_track;8:c=!music_enable?GUAN:music_status==4?CUO:music_status==3?JIE:music_status!=2?ZAI:BO;9:c=!music_enable?BI2:music_status==4?WU:music_status==3?SHU:music_status!=2?RU:FANG;endcase
   9:case(col)0:c=AN;1:c=JIAN;2:c=YIN;3:c=COLON;5:c=click_enable?KAI:GUAN;6:c=click_enable?QI:BI2;endcase
   10:case(col)0:c=PIN;1:c=PU;2:c=COLON;4:c=visual_mode==1?ZHU:visual_mode==2?JING:visual_mode==3?BO2:GUAN;5:c=visual_mode==1?ZHUANG:visual_mode==2?XIANG2:visual_mode==3?XING:BI2;endcase
   11:case(col)0:c=WEN;1:c=DU;2:c=COLON;4:c=temperature[6]?MINUS:PLUS;5,6,7:c=digit(temp_d,col-5);endcase
  endcase
 end end
// Clock 2: glyph row g*24+row read (masked by v2 for SP); clock 3: ink/dim.
reg [4:0] lx2;reg p2,s2,v2;reg [23:0] r1,r2;
wire [23:0] fr2;
osd_font_rom font(.clk(clk),.addr({c,4'b0}+{c,3'b0}+ly),.q(fr2));
wire ink=v2&&fr2[5'd23-lx2];
always @(posedge clk or posedge rst)begin
 if(rst)begin lx2<=0;p2<=0;s2<=0;v2<=0;r1<=0;r2<=0;out_rgb<=0;end
 else begin
  r1<=rgb;lx2<=lx1;p2<=p1;s2<=sel;v2<=c!=SP;r2<=r1;
  out_rgb<=r2;if(p2)out_rgb<={2'b0,r2[23:18],2'b0,r2[15:10],2'b0,r2[7:2]};if(p2&&ink)out_rgb<=s2?24'hffff00:24'hffffff;
 end
end
endmodule

// Registered-read glyph ROM, 1680 x 24. TD: EG_LOGIC_BRAM in BRAM32K (the
// 9K blocks are nearly full); ModelSim: the equivalent inferred array.
// Absolute paths: TD and ModelSim use different relative-path bases.
module osd_font_rom(input clk,input [10:0] addr,output [23:0] q);
`ifdef MODEL_TECH
reg [23:0] rom[0:1679];reg [23:0] q_r;
initial $readmemh("G:/ANLU_Project/digital photo frame3.0/user_source/hdl_source/font24_rows.mem",rom);
always @(posedge clk)q_r<=rom[addr];
assign q=q_r;
`else
EG_LOGIC_BRAM #(.DATA_WIDTH_A(24),.DATA_WIDTH_B(24),.ADDR_WIDTH_A(11),.ADDR_WIDTH_B(11),
 .DATA_DEPTH_A(1680),.DATA_DEPTH_B(1680),.MODE("SP"),.REGMODE_A("NOREG"),.RESETMODE("SYNC"),.IMPLEMENT("32K"),
 .INIT_FILE("G:/ANLU_Project/digital photo frame3.0/user_source/hdl_source/font24_rows.mif"))
 rom(.dia(24'd0),.addra(addr),.cea(1'b1),.ocea(1'b0),.clka(clk),.wea(1'b0),.rsta(1'b0),.bea(1'b0),
 .dib(24'd0),.addrb(11'd0),.ceb(1'b0),.oceb(1'b0),.clkb(1'b0),.web(1'b0),.rstb(1'b0),.beb(1'b0),.doa(q),.dob());
`endif
endmodule
