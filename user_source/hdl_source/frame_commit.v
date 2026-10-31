module frame_commit #(parameter integer ENABLE_EFFECTS=0,PER_PHOTO=0,BANK_BITS=2)(
    input clk,rst,frame_req,input source_clk,source_rst,
    input [BANK_BITS-1:0] requested_bank, input requested_valid,
    output reg [BANK_BITS-1:0] active_bank, output reg active_valid,
    output memory_req, output frame_start,input [1:0] transition_mode,
    output reg [7:0] alpha,output reg [9:0] reveal,
    input source_ready,input [24:0] requested_settings,
    output reg [24:0] active_settings
);
// Source mailbox is stable before the toggle crosses three pixel clocks.
// Requests are key/frame-rate events; consecutive events must be >4 pixel clocks.
reg [BANK_BITS-1:0] mailbox_bank,pending_bank;
reg mailbox_valid,pending_valid,mailbox_toggle;
reg [24:0] mailbox_settings,pending_settings;
reg captured_toggle;reg [2:0] capture_sync;
localparam [24:0] DEFAULT_SETTINGS={4'd0,7'd0,5'd10,9'd128};
reg [2:0] toggle_sync;
reg req_q;
reg [1:0] req_delay;
reg [1:0] effect_state;
assign frame_start = frame_req && !req_q;
assign memory_req = req_delay[1];
always @(posedge source_clk or posedge source_rst) begin
    if(source_rst) begin mailbox_bank<=0;mailbox_valid<=0;mailbox_toggle<=0;
      mailbox_settings<=DEFAULT_SETTINGS;capture_sync<=0;end
    else begin
     capture_sync<={capture_sync[1:0],captured_toggle};
     if((!PER_PHOTO || source_ready) && capture_sync[2]==mailbox_toggle &&
       (requested_bank!=mailbox_bank || requested_valid!=mailbox_valid ||
        (PER_PHOTO && requested_settings!=mailbox_settings))) begin
        mailbox_bank<=requested_bank;mailbox_valid<=requested_valid;
        if(PER_PHOTO)mailbox_settings<=requested_settings;
        mailbox_toggle<=~mailbox_toggle;
     end
    end
end
always @(posedge clk or posedge rst) begin
    if(rst) begin
        toggle_sync<=0;pending_bank<=0;pending_valid<=0;
        active_bank<=0;active_valid<=0;req_q<=0;req_delay<=0;
        alpha<=255;reveal<=640;effect_state<=0;
        pending_settings<=DEFAULT_SETTINGS;active_settings<=DEFAULT_SETTINGS;captured_toggle<=0;
    end else begin
        toggle_sync<={toggle_sync[1:0],mailbox_toggle};
        if(toggle_sync[2]!=toggle_sync[1]) begin
            pending_bank<=mailbox_bank;pending_valid<=mailbox_valid;
            pending_settings<=mailbox_settings;captured_toggle<=toggle_sync[1];
        end
        req_q<=frame_req;req_delay<={req_delay[0],frame_req};
        if(frame_start) begin
          if(active_bank==pending_bank)active_settings<=pending_settings;
          if(!ENABLE_EFFECTS || !active_valid || !pending_valid || (PER_PHOTO && active_settings[24:21]==pending_settings[24:21])) begin
            active_bank<=pending_bank;active_valid<=pending_valid;
            active_settings<=pending_settings;
            alpha<=255;reveal<=640;effect_state<=0;
          end else case(effect_state)
            0:if(pending_bank!=active_bank) begin
              case(transition_mode)
                1:begin effect_state<=1;alpha<=239;end
                2:begin active_bank<=pending_bank;active_settings<=pending_settings;effect_state<=3;reveal<=0;end
                default:begin active_bank<=pending_bank;active_settings<=pending_settings;alpha<=255;reveal<=640;end
              endcase
            end
            1:if(alpha==0) begin active_bank<=pending_bank;active_settings<=pending_settings;effect_state<=2;end
              else alpha<=(alpha<=16)?0:alpha-16;
            2:if(alpha>=239) begin alpha<=255;effect_state<=0;end
              else alpha<=alpha+16;
            3:if(reveal>=600) begin reveal<=640;effect_state<=0;end
              else reveal<=reveal+40;
          endcase
        end
    end
end
endmodule
