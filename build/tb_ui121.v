`timescale 1ns/1ps
module tb_ui121;
reg clk=0;always #5 clk=~clk;
reg rst=1,k1=1,k2=1,k3=1,k4=1;reg [3:0] dip=0;
wire ne,ae,pe,oe,se;wire [2:0] page;wire signed [8:0] br;
wire [8:0] co;wire [4:0] sc;wire [1:0] tr,su;wire [1:0] ai;wire mu,me,ce,ve;
display_controls4 #(.DEBOUNCE(2)) ctrl(clk,rst,k1,k2,k3,k4,dip,ne,ae,pe,page,br,co,sc,tr,su,oe,se,ai,mu,me,ce,ve);
integer nc=0,pc=0,ac=0,i,j,selected;
always @(posedge clk)begin if(ne)nc=nc+1;if(pe)pc=pc+1;if(ae)ac=ac+1;end
task tick;begin @(negedge clk);end endtask
task press;input integer key;begin
 k1=key!=1;k2=key!=2;k3=key!=3;k4=key!=4;
 repeat(12)tick;k1=1;k2=1;k3=1;k4=1;repeat(12)tick;
end endtask
task choose;input [3:0] value;begin dip=value;repeat(16)tick;end endtask
reg [9:0] x=0,y=0;wire [23:0] rgb;
text_layers layers(24'h80a0c0,1'b1,x,y,page,br,co,sc,tr,su,2'd1,1'b1,8'd0,oe,se,10'd0,rgb,ai,mu,me,ce,ve);
reg [37:0] before_values;
initial begin
 repeat(4)tick;rst=0;repeat(16)tick;if(sc!=10)$fatal(1,"Default scale must be 100%%");
 press(1);press(2);if(pc!=1 || nc!=1 || ac!=0)$fatal(1,"Separate playback keys");
 k1=0;repeat(12)tick;k2=0;repeat(35)tick;k1=1;repeat(12)tick;k2=1;repeat(12)tick;
 if(pc!=1 || nc!=1 || ac!=1)$fatal(1,"Staggered chord leaked page event or repeated");
 k1=0;k2=0;repeat(15)tick;k1=1;k2=1;repeat(15)tick;
 if(pc!=1 || nc!=1 || ac!=2)$fatal(1,"Simultaneous chord");
 k1=0;tick;k1=1;repeat(12)tick;if(pc!=1)$fatal(1,"Bounce accepted");
 choose(1);if(page!=4)$fatal(1,"Brightness DIP");
 repeat(10)press(4);if(br!=96)$fatal(1,"Brightness clamp");
 repeat(15)press(3);if(br!=-96)$fatal(1,"Brightness lower clamp");
 x=16;y=12;#1;if(rgb!=24'hffff00)$fatal(1,"Active parameter label is not yellow");
 x=16+10*16;y=18;#1;if(rgb!=24'hffffff)$fatal(1,"Value sign is not white");
 x=8;y=8;#1;if(rgb!=24'h405060)$fatal(1,"Panel blend");
 x=8;y=32;#1;if(rgb!=24'h80a0c0)$fatal(1,"Single row extends below y32");
 x=360;y=12;#1;if(rgb!=24'h80a0c0)$fatal(1,"Single row extends beyond x360");
 choose(2);repeat(12)press(4);if(co!=256)$fatal(1,"Contrast upper clamp");
 repeat(18)press(3);if(co!=32)$fatal(1,"Contrast lower clamp");
 choose(4);press(4);if(sc!=11)$fatal(1,"Scale");press(3);if(sc!=10)$fatal(1,"Scale decrement");
 choose(8);press(3);if(tr!=2)$fatal(1,"Effect decrement wraps");
 choose(3);press(4);if(!se || su!=1)$fatal(1,"Subtitle");press(3);if(se)$fatal(1,"Subtitle toggle");
 before_values={ve,ai,mu,me,ce,br,co,3'd0,sc,tr,su,1'b0,se};
 for(i=0;i<16;i=i+1)begin
  choose(i);
  selected=i==0?0:i==1?4:i==2?5:i==4?3:i==8?2:
    i==5?7:i==3||i==6||i==9||i==10||i==12?1:6;
  if(page!=selected)$fatal(1,"DIP combination %d",i);
  if(page==6)begin press(3);press(4);
   if({ve,ai,mu,me,ce,br,co,3'd0,sc,tr,su,1'b0,se}!=before_values)$fatal(1,"Overview altered values");
  end
 end
 x=16;y=12;#1;if(rgb!=24'hffffff)$fatal(1,"Overview must not have a yellow selection");
 x=16+16*16;y=12+6*16;#1;if(layers.c!=32)$fatal(1,"Auto label spacing");
 x=16+17*16;#1;if(layers.c!=49)$fatal(1,"Overview autoplay value");
 choose(5);x=16;y=12;#1;if(rgb!=24'hffff00)$fatal(1,"Audio label must be yellow");
 if(ai!=0 || mu || me || ce)$fatal(1,"Audio defaults");
 press(4);if(!mu || me || ce)$fatal(1,"Mute must preserve toggles");
 press(3);if(ai!=1)$fatal(1,"Select music");press(4);if(!me)$fatal(1,"Music on");
 press(4);if(me)$fatal(1,"Music off");press(4);if(!me)$fatal(1,"Music on again");press(3);if(ai!=2)$fatal(1,"Select click");
 press(4);if(!ce || !me)$fatal(1,"Independent simultaneous enables");
 press(3);if(ai!=3 || ve)$fatal(1,"Fourth audio item default");
 press(4);if(!ve || !me || !ce || !mu)$fatal(1,"Visual toggle altered audio");
 repeat(150)tick;
 press(4);if(ve)$fatal(1,"Visual off");press(4);
 press(3);if(ai!=0 || !ve)$fatal(1,"Four item audio cycle");press(4);if(mu || !me || !ce)$fatal(1,"Unmute restores settings");
 choose(15);press(3);press(4);if(mu || !me || !ce || !ve)$fatal(1,"Overview changed audio");
 choose(5);if(ai!=0)$fatal(1,"Reentry selects mute");
 choose(4);
 repeat(20)press(3);if(sc!=3)$fatal(1,"Scale minimum 30%% clamp");
 for(j=3;j<=20;j=j+1)begin
  if(sc!=j)$fatal(1,"Scale increment step %d",j);
  repeat(150)tick;
  x=16+10*16;y=18;#1;if(layers.c!=48+(j*10)/100)$fatal(1,"Scale OSD hundreds");
  x=16+11*16;#1;if(layers.c!=48+j%10)$fatal(1,"Scale OSD tens");
  x=16+12*16;#1;if(layers.c!=48)$fatal(1,"Scale OSD units");
  press(4);
 end
 if(sc!=20)$fatal(1,"Scale upper clamp");repeat(3)press(4);if(sc!=20)$fatal(1,"Scale must not wrap");
 for(j=19;j>=3;j=j-1)begin press(3);if(sc!=j)$fatal(1,"Scale decrement step");end
 press(3);if(sc!=3)$fatal(1,"Scale lower clamp");
 $display("SCALE_30_TO_200_TEN_PERCENT_KEYS_CLAMPS_OSD_DIGITS_PASS");
 choose(1);k4=0;repeat(12)tick;choose(2);k4=1;repeat(12)tick;
 if(co!=32)$fatal(1,"Held key across DIP change modified new parameter");
 choose(1);repeat(150)tick;
 $display("DIP_ALL_MODES_CHORD_PREV_NEXT_READONLY_OSD_DIGITS_PASS");$finish;
end
initial begin #200000;$fatal(1,"UI timeout");end
endmodule
