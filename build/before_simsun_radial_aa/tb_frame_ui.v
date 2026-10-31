`timescale 1ns/1ps
module tb_frame_ui;
reg clk=0;always #5 clk=~clk;
reg rst=1,k1=1,k2=1,k3=1,k4=1;reg [3:0] dip=0;
wire ne,ae,pe,oe,se,mu,me,ce,ve,toast,reset_all;
wire [2:0] music_track;reg [2:0] track_count=0;wire [3:0] page;wire signed [8:0] br;wire [8:0] co;
wire signed [6:0] temperature;
wire [4:0] sc;wire [1:0] tr,su,ai,vm,speed;
display_controls4 #(.DEBOUNCE(2),.TOAST_CYCLES(150),.HAS_SD_AUDIO(1)) ctrl(
 .clk(clk),.rst(rst),.key1(k1),.key2(k2),.key3(k3),.key4(k4),.dip(dip),
 .next_event(ne),.auto_event(ae),.prev_event(pe),.page(page),.brightness(br),.contrast(co),.scale(sc),.temperature(temperature),
 .transition(tr),.subtitle(su),.osd_enable(oe),.subtitle_enable(se),.audio_item(ai),.mute(mu),
 .music_enable(me),.click_enable(ce),.visual_enable(ve),.visual_mode(vm),.speed(speed),.speed_toast(toast),.reset_all_event(reset_all),.track_count(track_count),.music_track(music_track));
integer nc=0,pc=0,ac=0,rc=0,i,j,expected,tc;
always @(posedge clk)begin if(ne)nc=nc+1;if(pe)pc=pc+1;if(ae)ac=ac+1;if(reset_all)rc=rc+1;end
task tick;begin @(negedge clk);end endtask
task press;input integer k;begin
 k1=k!=1;k2=k!=2;k3=k!=3;k4=k!=4;repeat(12)tick;
 k1=1;k2=1;k3=1;k4=1;repeat(12)tick;
end endtask
task choose;input [3:0] d;begin dip=d;repeat(20)tick;end endtask
task chord34;begin
 k3=0;repeat(12)tick;k4=0;repeat(30)tick;k3=1;repeat(12)tick;k4=1;repeat(12)tick;
end endtask
reg [9:0] x=0,y=0;wire [23:0] rgb;
text_layers #(.ENABLE_TEMPERATURE(1)) layers(.rgb(24'h80a0c0),.de(1'b1),.x(x),.y(y),.page(page),.brightness(br),.contrast(co),.scale(sc),.temperature(temperature),
 .transition(tr),.subtitle(su),.bank(4'd1),.auto_enabled(1'b1),.error_code(8'd0),.osd_enable(oe),.subtitle_enable(se),
 .scroll(10'd0),.music_track(music_track),.music_status(3'd2),.out_rgb(rgb),.audio_item(ai),.mute(mu),.music_enable(me),.click_enable(ce),.visual_enable(ve),.visual_mode(vm),.speed(speed),.speed_toast(toast));
initial begin
 repeat(4)tick;rst=0;repeat(16)tick;
 if(sc!=10 || speed!=1 || mu || me || ce || vm)$fatal(1,"Defaults");
 press(1);press(2);if(pc!=1 || nc!=1 || ac!=0)$fatal(1,"Picture keys");
 k1=0;repeat(12)tick;k2=0;repeat(30)tick;k1=1;repeat(12)tick;k2=1;repeat(12)tick;
 if(pc!=1 || nc!=1 || ac!=1)$fatal(1,"K1 K2 chord leakage");
 for(i=0;i<16;i=i+1)begin
  choose(i);expected=i==0?0:i==1?4:i==2?5:i==3?1:i==4?3:i==5?7:i==9?8:i==8?2:6;
  if(page!=expected || se)$fatal(1,"DIP mapping/subtitles removed");
 end
 choose(1);repeat(10)press(4);if(br!=96)$fatal(1,"Brightness clamp");
 x=16;y=12;#1;if(rgb!=24'hffff00)$fatal(1,"Yellow active label");
 x=8;y=32;#1;if(rgb!=24'h80a0c0)$fatal(1,"Single row height");
 chord34;if(br!=0)$fatal(1,"Reset brightness chord leaked adjustment");
 choose(9);repeat(9)press(4);if(temperature!=48 || br!=0)$fatal(1,"Warm limit/isolation");
 x=16;y=12;#1;if(layers.c!="T" || rgb!=24'hffff00)$fatal(1,"Temperature label");
 chord34;if(temperature!=0)$fatal(1,"Temperature reset");
 repeat(9)press(3);if(temperature!=-48)$fatal(1,"Cold limit");
 repeat(150)tick;
 x=176;#1;if(layers.c!="-")$fatal(1,"Cold OSD sign");
 k4=0;repeat(12)tick;choose(1);k4=1;repeat(15)tick;
 if(br!=0 || temperature!=-48)$fatal(1,"Temperature held key leaked into brightness");
 choose(9);chord34;
 choose(2);press(4);chord34;if(co!=128)$fatal(1,"Reset contrast");
 choose(8);press(4);chord34;if(tr!=0)$fatal(1,"Reset effect");
 choose(4);repeat(25)press(3);if(sc!=3)$fatal(1,"Zoom minimum");
 for(j=3;j<=20;j=j+1)begin
  if(sc!=j)$fatal(1,"Zoom step");repeat(150)tick;
  x=16+10*16;y=18;#1;if(layers.c!=48+(j*10)/100)$fatal(1,"Zoom OSD hundreds");
  x=16+11*16;#1;if(layers.c!=48+j%10)$fatal(1,"Zoom OSD tens");
  press(4);
 end
 if(sc!=20)$fatal(1,"Zoom upper clamp");chord34;if(sc!=10)$fatal(1,"Reset zoom");
 choose(5);press(4);if(!mu)$fatal(1,"Mute");chord34;if(mu)$fatal(1,"Reset mute");
 press(3);press(4);if(ai!=1 || !me)$fatal(1,"Music test");
 press(1);press(2);
 k1=0;k2=0;repeat(25)tick;k1=1;k2=1;repeat(15)tick;
 if(pc!=1 || nc!=1 || ac!=1)$fatal(1,"Music navigation leaked picture/autoplay actions");
 x=16+10*16;y=12;#1;if(layers.c!="t")$fatal(1,"MUSIC test label");
 track_count=4;press(2);if(music_track!=1)$fatal(1,"Select SD track1");
 x=16+10*16;y=12;#1;if(layers.c!="1")$fatal(1,"SD track OSD");
 press(1);if(music_track!=0)$fatal(1,"Return test");press(1);if(music_track!=4)$fatal(1,"Previous wraps last SD");
 press(2);if(music_track!=0 || nc!=1 || pc!=1)$fatal(1,"Next wraps test without photo");
 press(3);press(4);if(!me || !ce)$fatal(1,"Music/click independent enables");
 chord34;if(ce || !me)$fatal(1,"Reset click changed music");press(4);
 press(3);press(4);if(vm!=1)$fatal(1,"Bars selection");press(4);if(vm!=2)$fatal(1,"Radial selection");
 press(4);if(vm!=3)$fatal(1,"Wave selection");press(4);if(vm!=0)$fatal(1,"Visual wraps to OFF");press(4);press(4);press(4);if(vm!=3)$fatal(1,"Wave reselection");
 y=12;x=176;#1;if(layers.c!="W")$fatal(1,"WAVE label");x=192;#1;if(layers.c!="A")$fatal(1,"WAVE label");
 x=208;#1;if(layers.c!="V")$fatal(1,"WAVE label");x=224;#1;if(layers.c!="E")$fatal(1,"WAVE label");x=0;y=0;
 repeat(150)tick;
 chord34;if(vm!=0 || !me || !ce)$fatal(1,"Reset visual");
 choose(3);press(4);if(speed!=2)$fatal(1,"Speed page");chord34;if(speed!=1)$fatal(1,"Reset speed");
 choose(0);k3=0;k4=0;wait(toast);tick;
 if(speed!=2)$fatal(1,"Playback chord speed");
 tc=0;while(toast)begin tc=tc+1;tick;end
 if(tc!=150)$fatal(1,"Toast duration %d",tc);
 repeat(25)tick;if(speed!=2)$fatal(1,"Held chord repeats");k3=1;k4=1;repeat(15)tick;
 chord34;if(speed!=0)$fatal(1,"Speed wraps to fast");chord34;if(speed!=1)$fatal(1,"Speed medium");
 choose(1);press(4);choose(2);press(4);choose(4);press(4);choose(8);press(4);
 choose(9);press(4);choose(15);x=16;y=204;#1;if(layers.c!="T")$fatal(1,"Overview temperature missing");
 x=16;y=12;#1;if(layers.c!="O")$fatal(1,"Overview header truncated");
 x=8;y=8;#1;if(rgb!=24'h202830)$fatal(1,"OSD contrast background");chord34;
 if(br!=0 || co!=128 || sc!=10 || tr!=0 || temperature!=0 || mu || me || ce || vm || speed!=1 || rc!=1)$fatal(1,"Overview defaults");
 choose(1);k4=0;repeat(12)tick;choose(2);k4=1;repeat(15)tick;
 if(co!=128)$fatal(1,"Held key across DIP");
 x=32;y=444;#1;if(rgb!=24'h80a0c0)$fatal(1,"Subtitle pixels still present");
 $display("TEMPERATURE_DIP_1001_LIMITS_OSD_CHORD_OVERVIEW_RESET_PASS");
 $display("FRAME_UI_CHORD_CONTEXT_MUSIC_DIP_DEFAULTS_ZOOM_TOAST_PASS");$finish;
end
initial begin #1000000;$fatal(1,"UI timeout");end
endmodule
