`timescale 1ns/1ps
module tb_temperature;
reg [23:0] rgb;
reg signed [8:0] brightness;
reg [8:0] contrast;
reg signed [6:0] temperature;
wire [23:0] adjusted;
runtime_adjust #(.ENABLE_TEMPERATURE(1)) dut(rgb,brightness,contrast,adjusted,temperature);
integer t,b,c,v,r,g,bl;
function integer channel;
 input integer value,br,co,offset;
 integer result;
 begin
  result=(((value-128)*co)>>>7)+128+br+offset;
  channel=result<0?0:result>255?255:result;
 end
endfunction
reg source_clk=0,clk=0;always #5 source_clk=~source_clk;always #7 clk=~clk;
reg rst=1,frame=0;
reg [54:0] source_data=55'h5000040080;
wire [54:0] parameters;
parameter_mailbox #(.WIDTH(55)) mailbox(source_clk,rst,source_data,clk,rst,frame,parameters);
reg [54:0] first,second;
task boundary;begin @(negedge clk);frame=1;@(negedge clk);frame=0;end endtask
initial begin
 for(t=-48;t<=48;t=t+8)for(b=-96;b<=96;b=b+16)for(c=32;c<=256;c=c+16)for(v=0;v<256;v=v+1)begin
  temperature=t;brightness=b;contrast=c;rgb={v[7:0],8'(v^85),8'(255-v)};#1;
  r=channel(v,b,c,t);g=channel(v^85,b,c,0);bl=channel(255-v,b,c,-t);
  if(adjusted!=={r[7:0],g[7:0],bl[7:0]})$fatal(1,"Temperature RGB clamp/sign mismatch");
  if(t==0 && b==0 && c==128 && adjusted!==rgb)$fatal(1,"Neutral must preserve RGB888");
 end
 $display("TEMPERATURE_ALL_STEPS_BRIGHT_CONTRAST_RGB_SATURATION_NEUTRAL_IDENTITY_PASS");
 repeat(5)@(negedge clk);rst=0;
 first=55'h5000040080;first[54]=1;first[53:47]=7'd48;first[10:8]=0;
 second=55'h5000040080;second[54]=0;second[53:47]=-7'sd48;second[10:8]=4;
 @(negedge source_clk);source_data=first;repeat(12)@(negedge clk);
 source_data=second;repeat(12)@(negedge clk);
 if(parameters!==55'h5000040080)$fatal(1,"Temperature CDC changed mid-frame");
 boundary;
 if(parameters!==first)$fatal(1,"First complete temperature transaction missing");
 repeat(16)@(negedge clk);
 if(parameters!==first)$fatal(1,"In-flight temperature changed pixels");
 boundary;
 if(parameters!==second)$fatal(1,"Second temperature transaction not atomic");
 $display("TEMPERATURE_55BIT_ASYNC_MAILBOX_ATOMIC_PENDING_UPDATES_PASS");$finish;
end
initial begin #2000000;$fatal(1,"Temperature test timeout");end
endmodule
