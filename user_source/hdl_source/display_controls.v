// Existing active-low keys, no extra board pins. Events are debounced and
// emitted on release, preventing a dual-key chord from also changing images.
module display_controls #(parameter integer DEBOUNCE=2_000_000,HOLD=100_000_000)(
 input clk,rst,key1,key2,
 output reg next_event,auto_event,
 output reg [2:0] page,
 output reg signed [8:0] brightness,output reg [8:0] contrast,
 output reg [1:0] scale,transition,subtitle,
 output reg osd_enable,subtitle_enable
);
reg [1:0] meta,sync,stable,candidate;
reg [26:0] debounce_count,hold_count;
reg [1:0] gesture;
reg chord,fired;
always @(posedge clk or posedge rst) begin
 if(rst) begin
  meta<=3;sync<=3;stable<=3;candidate<=3;debounce_count<=0;hold_count<=0;
  gesture<=0;chord<=0;fired<=0;next_event<=0;auto_event<=0;page<=0;
  brightness<=0;contrast<=128;scale<=0;transition<=0;subtitle<=0;
  osd_enable<=0;subtitle_enable<=0;
 end else begin
  meta<={key2,key1};sync<=meta;next_event<=0;auto_event<=0;
  if(sync!=candidate) begin candidate<=sync;debounce_count<=0;end
  else if(debounce_count<DEBOUNCE) debounce_count<=debounce_count+1'b1;
  else stable<=candidate;
  if(stable!=3) begin
   gesture<=gesture | ~stable;
   if(stable==0) begin
    chord<=1;
    if(!fired) begin
     if(hold_count>=HOLD-1) begin
      page<=(page==6)?0:page+1'b1;fired<=1;
     end else hold_count<=hold_count+1'b1;
    end
   end else hold_count<=0;
  end else begin
   if(gesture!=0 && !chord) begin
    case(page)
     0:begin next_event<=gesture[0];auto_event<=gesture[1];end
     1:if(gesture[0]) subtitle<=subtitle+1'b1;else subtitle_enable<=~subtitle_enable;
     2:if(gesture[0]) transition<=(transition==2)?0:transition+1'b1;else transition<=0;
     3:if(gesture[0]) scale<=scale+1'b1;else scale<=0;
     4:if(gesture[0]) begin if(brightness<96) brightness<=brightness+16;end
       else if(brightness> -96) brightness<=brightness-16;
     5:if(gesture[0]) begin if(contrast<256) contrast<=contrast+16;end
       else if(contrast>32) contrast<=contrast-16;
     6:if(gesture[0]) osd_enable<=~osd_enable;
       else begin brightness<=0;contrast<=128;scale<=0;transition<=0;osd_enable<=0;subtitle_enable<=0;end
    endcase
   end
   gesture<=0;chord<=0;fired<=0;hold_count<=0;
  end
 end
end
endmodule
