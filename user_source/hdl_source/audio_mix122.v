// Original stereo sample cadence is preserved even during mute.
// Prompt on actual committed bank changes; initial image does not beep.
module audio_mix122 #(parameter CLICK_SAMPLES=4800,BANK_BITS=2)(
 input clk,rst,sample_valid,input [23:0] left_in,right_in,
 input mute,music_enable,click_enable,input [BANK_BITS-1:0] bank,input display_valid,
 output [23:0] left_out,right_out);
reg seen;reg [BANK_BITS-1:0] previous_bank;
reg [12:0] remaining;
// Two concurrent DDS voices at a nominal 48 kHz sample rate:
// G5 = 783.69 Hz, B5 = 988.04 Hz (16-bit phase quantization).
reg [15:0] phase_g5,phase_b5;
wire signed [24:0] g5=phase_g5[15] ? -25'sd375000 : 25'sd375000;
wire signed [24:0] b5=phase_b5[15] ? -25'sd375000 : 25'sd375000;
wire signed [24:0] prompt=(remaining==0 || !click_enable)?25'sd0:
 g5+b5;
wire signed [24:0] left_sum=(music_enable?$signed({left_in[23],left_in}):25'sd0)+prompt;
wire signed [24:0] right_sum=(music_enable?$signed({right_in[23],right_in}):25'sd0)+prompt;
function [23:0] saturate;
 input signed [24:0] value;
 begin saturate=value>25'sd8388607 ? 24'h7fffff:
 value < -25'sd8388608 ? 24'h800000:value[23:0];end
endfunction
assign left_out=mute?24'd0:saturate(left_sum);
assign right_out=mute?24'd0:saturate(right_sum);
always @(posedge clk or posedge rst)begin
 if(rst)begin seen<=0;previous_bank<=0;remaining<=0;phase_g5<=0;phase_b5<=0;end
 else begin
  if(display_valid)begin seen<=1;previous_bank<=bank;end
  if(!click_enable)begin remaining<=0;phase_g5<=0;phase_b5<=0;end
  else if(display_valid && seen && bank!=previous_bank)begin remaining<=CLICK_SAMPLES;phase_g5<=0;phase_b5<=0;end
  else if(sample_valid && remaining!=0)begin
   remaining<=remaining-1'b1;
   phase_g5<=phase_g5+16'd1070;
   phase_b5<=phase_b5+16'd1349;
  end
 end
end
endmodule

