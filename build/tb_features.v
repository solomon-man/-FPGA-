`timescale 1ns/1ps
module tb_features;
reg clk=0;always #5 clk=~clk;
reg rst=1,k1=1,k2=1,k3=1,k4=1;wire next_event,auto_event;wire [3:0] page;
wire signed [8:0] br;wire [8:0] co;wire [4:0] sc;wire [1:0] tr,su;wire [1:0] ai;wire mu,me,ce,ve;wire oe,se;
reg [3:0] dip=0;wire prev_event;
display_controls4 #(.DEBOUNCE(2),.HOLD(16)) ctrl(clk,rst,k1,k2,k3,k4,dip,next_event,auto_event,prev_event,page,br,co,sc,tr,su,oe,se,ai,mu,me,ce,ve,,,,,3'd0,,);
integer next_count=0,auto_count=0;
always @(posedge clk)begin if(next_event)next_count=next_count+1;if(auto_event)auto_count=auto_count+1;end
task press;input integer key;begin
 @(negedge clk);k1=key!=1;k2=key!=2;k3=key!=3;k4=key!=4;repeat(12)@(negedge clk);
 k1=1;k2=1;k3=1;k4=1;repeat(12)@(negedge clk);
end endtask
task hold_key;input integer key;begin
 @(negedge clk);k3=key!=3;k4=key!=4;
 repeat(45)@(negedge clk);k3=1;k4=1;
 repeat(12)@(negedge clk);
end endtask
reg [23:0] ar;reg signed [8:0] abr;reg [8:0] aco;wire [23:0] adjusted;
runtime_adjust adjust(ar,abr,aco,adjusted,7'sd0);
reg fs=0,sd=0;reg [9:0] x=0,y=0;reg [23:0] rgb=0;reg [4:0] scale=10;reg [1:0] bank=0;
wire [23:0] srgb;wire sde,ready;
thumbnail_scaler scaler(clk,rst,fs,sd,bank,x,y,rgb,scale,srgb,sde,ready);
reg req=0,wvalid=0;reg [1:0] wanted=0,mode=0;
wire [1:0] active;wire av,mreq,fstart;wire [7:0] alpha;wire [9:0] reveal;
frame_commit #(.ENABLE_EFFECTS(1)) commit(clk,rst,req,clk,rst,wanted,wvalid,active,av,mreq,fstart,mode,alpha,reveal);
reg [46:0] source_data=47'h5000040080;
wire [46:0] p_data;
parameter_mailbox mailbox(clk,rst,source_data,clk,rst,fs,p_data);
task boundary;begin @(negedge clk);fs=1;@(negedge clk);fs=0;end endtask
task frame;begin @(negedge clk);req=1;repeat(3)@(negedge clk);req=0;repeat(3)@(negedge clk);end endtask
function [23:0] pattern;
input integer px,py;begin pattern={px[7:0],py[7:0],8'had};end endfunction
function [23:0] quantize;input [23:0] p;
begin quantize={p[23:19],p[23:21],p[15:10],p[15:14],p[7:3],p[7:5]};end endfunction
task sample;input integer px,py,sm;input [23:0] expected;
begin
 @(negedge clk);x=px;y=py;sd=1;scale=sm;rgb=24'h123456;
 @(posedge clk);#1;if(srgb!==expected || !sde)$fatal(1,"Scale %d at %d,%d got %h wanted %h",sm,px,py,srgb,expected);
end endtask
integer v,c,b,e,i,j;
reg [9:0] tx=0,ty=0;reg tos=0,tsub=0;
wire [23:0] layered;
text_layers layers(.rgb(24'h80a0c0),.de(1'b1),.x(tx),.y(ty),.page(4'd0),
 .brightness(-9'sd32),.contrast(9'd160),.scale(5'd15),.transition(2'd2),
 .subtitle(2'd0),.bank(4'd2),.auto_enabled(1'b1),.error_code(8'd41),
 .osd_enable(tos),.subtitle_enable(tsub),.scroll(10'd0),.music_track(3'd0),.music_status(3'd0),.visual_mode(2'd0),.speed(2'd1),.speed_toast(1'b0),.audio_item(2'd0),.mute(1'b0),.music_enable(1'b0),.click_enable(1'b0),.visual_enable(1'b0),.out_rgb(layered));
initial begin
 repeat(4)@(negedge clk);rst=0;
 for(b=-96;b<=96;b=b+16)for(c=32;c<=256;c=c+16)for(v=0;v<256;v=v+1)begin
  abr=b;aco=c;ar={v[7:0],v[7:0],v[7:0]};#1;
  e=(((v-128)*c)>>>7)+128+b;if(e<0)e=0;if(e>255)e=255;
  if(adjusted!=={e[7:0],e[7:0],e[7:0]})$fatal(1,"Adjust mismatch v%d b%d c%d got%h",v,b,c,adjusted);
 end
 $display("RUNTIME_ALL_GRAY_ALL_MENU_PARAMS_PASS");
 source_data={3'd2,3'd4,1'b1,2'd2,2'd2,1'b1,2'd3,1'b1,1'b1,1'b1,1'b0,9'd32,9'd160,3'd4,2'd2,2'd1,2'd3,2'b11};
 repeat(15)@(negedge clk);
 if(p_data!=47'h5000040080)$fatal(1,"Parameter update mid frame");
 boundary();if(p_data!=source_data)$fatal(1,"Atomic parameter update");
 source_data=47'h5000040080;repeat(15)@(negedge clk);boundary();
 if(p_data!=source_data)$fatal(1,"Mailbox ACK update");
 $display("PARAMETER_ATOMIC_FRAME_CDC_PASS");
 scale=10;boundary();
 for(j=0;j<480;j=j+1)begin
  for(i=0;i<640;i=i+1)begin
   @(negedge clk);sd=1;x=i;y=j;rgb=pattern(i,j);
   @(posedge clk);#1;if(srgb!==rgb)$fatal(1,"Scale original bypass");
  end
  @(negedge clk);sd=0;
 end
 for(b=3;b<=20;b=b+1)begin
  sample(320,240,b,24'h123456);
  if(b<10)begin
   sample(320-b*32,240-b*24,b,24'h123456);
   sample(319-b*32,240-b*24,b,0);
   sample(320+b*32,240,b,0);
   sample(320,240+b*24,b,0);
  end else begin sample(0,0,b,24'h123456);sample(639,479,b,24'h123456);end
 end
 @(negedge clk);sd=0;
 $display("SCALER_FULL_FRAME_BANK_BOUNDARY_MODES_PASS");
 wanted=0;wvalid=1;repeat(8)@(negedge clk);frame();if(!av)$fatal(1,"First picture");
 wanted=1;mode=1;repeat(8)@(negedge clk);
 for(i=0;i<16;i=i+1)begin frame();if(active!=0)$fatal(1,"Fade committed before black");end
 if(alpha!=0)$fatal(1,"Fadeout black");
 frame();if(active!=1 || alpha!=0)$fatal(1,"Commit at black");
 for(i=0;i<16;i=i+1)frame();
 if(alpha!=255)$fatal(1,"Fadein endpoint");
 wanted=2;mode=2;repeat(8)@(negedge clk);frame();
 if(active!=2 || reveal!=0)$fatal(1,"Wipe start");
 for(i=0;i<16;i=i+1)frame();
 if(reveal!=640)$fatal(1,"Wipe endpoint");
 wanted=3;mode=0;repeat(8)@(negedge clk);frame();
 if(active!=3 || alpha!=255 || reveal!=640)$fatal(1,"Hard cut");
 $display("FADE_OLD_BLACK_COMMIT_NEW_WIPE_PASS");$finish;
end
initial begin #10000000;$fatal(1,"Feature timeout");end
endmodule
