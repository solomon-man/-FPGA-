// Streaming RIFF/WAVE parser. PCM16, 48000 Hz, mono/stereo, arbitrary bounded
// fmt/JUNK/LIST chunks and odd-byte padding. Headerless PCM defaults to mono.
// All accesses remain sequential; raw sample rate is fixed by the 48 kHz sink.
module wav_pcm_reader #(parameter integer RAW_PCM_CHANNELS=1,RAW_ONLY=0)(
 input clk,rst,start,input [31:0] file_bytes,input raw_pcm,
 output reg sector_req,output reg [31:0] sector_lba,
 input [7:0] sector_data,input sector_valid,sector_end,
 output reg [31:0] pcm_data,output reg pcm_valid,input pcm_ready,
 output reg format_valid,done,error,output reg [7:0] error_code);
localparam IDLE=0,FETCH=1,WAIT=2,ADDR=3,LATENCY=4,PARSE=5,EMIT=6,FINISH=7,FAIL=8,PRECHECK=9,CHECK_READY=10;
localparam RIFF=0,CHUNK=1,FMT=2,SKIP=3,PCM=4;
reg [3:0] state,resume_state;reg [2:0] phase;
reg [7:0] mem[0:511],q;reg [8:0] rx,index;
reg [31:0] pos,riff_id,riff_size,wave_id,riff_end,chunk_id,chunk_size,left_count;
reg [4:0] field;
reg [15:0] encoding,channels,alignment,bits;
reg [31:0] rate,byte_rate;
reg fmt_ok,finish_pending;reg [1:0] component;reg [7:0] low_byte;reg [15:0] left_sample;
wire [31:0] length_now={q,chunk_size[23:0]};
reg [32:0] padded_length,remaining_in_riff;
reg chunk_bounds_ok;
// These checks settle during the BRAM-read pipeline before PARSE consumes q.
reg [31:0] file_payload_limit;
reg riff_header_ok,byte_bounds_ok,fmt_header_ok;
always @(posedge clk or posedge rst)begin
 if(rst)begin
  padded_length<=0;remaining_in_riff<=0;chunk_bounds_ok<=0;
  file_payload_limit<=0;riff_header_ok<=0;byte_bounds_ok<=0;fmt_header_ok<=0;
 end
 else begin
  padded_length<={1'b0,length_now}+{32'd0,length_now[0]};
  remaining_in_riff<={1'b0,riff_end}-{1'b0,pos}-1'b1;
  chunk_bounds_ok<=padded_length<=remaining_in_riff;
  file_payload_limit<=file_bytes-8;
  riff_header_ok<=riff_id==32'h46464952 && {q,wave_id[23:0]}==32'h45564157 &&
    file_bytes>=44 && riff_size>=36 && riff_size<=file_payload_limit;
  byte_bounds_ok<=pos<file_bytes && (RAW_ONLY || phase==RIFF || pos<riff_end);
  fmt_header_ok<=encoding==1 && (channels==1 || channels==2) && rate==48000 &&
    {q,bits[7:0]}==16 && alignment==(channels==1?2:4) && byte_rate==(channels==1?96000:192000);
 end
end
always @(posedge clk)begin
 if(state==WAIT && sector_valid)mem[rx]<=sector_data;
 q<=mem[index];
end
task fail;input [7:0] code;begin error<=1;error_code<=code;pcm_valid<=0;sector_req<=0;state<=FAIL;end endtask
always @(posedge clk or posedge rst)begin
 if(rst)begin
  state<=IDLE;resume_state<=IDLE;phase<=RIFF;rx<=0;index<=0;pos<=0;field<=0;
  riff_id<=0;riff_size<=0;wave_id<=0;riff_end<=0;chunk_id<=0;chunk_size<=0;left_count<=0;
  encoding<=0;channels<=0;alignment<=0;bits<=0;rate<=0;byte_rate<=0;
  fmt_ok<=0;finish_pending<=0;component<=0;low_byte<=0;left_sample<=0;
  sector_req<=0;sector_lba<=0;pcm_data<=0;pcm_valid<=0;format_valid<=0;done<=0;error<=0;error_code<=0;
 end else case(state)
  IDLE:if(start)begin
   state<=FETCH;phase<=RIFF;pos<=0;index<=0;sector_lba<=0;
   if(raw_pcm || RAW_ONLY)begin
    if((RAW_PCM_CHANNELS!=1 && RAW_PCM_CHANNELS!=2) || file_bytes==0 ||
       file_bytes[0] || (RAW_PCM_CHANNELS==2 && file_bytes[1]))fail(8'h65);
    else begin
     phase<=PCM;channels<=RAW_PCM_CHANNELS;riff_end<=file_bytes;
     left_count<=file_bytes;component<=0;format_valid<=1;
    end
   end
  end
  FETCH:if(pos>=file_bytes)fail(8'h61);else begin sector_req<=1;rx<=0;state<=WAIT;end
  WAIT:begin
   if(sector_valid)rx<=rx+1'b1;
   if(sector_end)begin sector_req<=0;index<=0;state<=ADDR;end
  end
  ADDR:state<=LATENCY;
  LATENCY:state<=PRECHECK;
  PRECHECK:state<=CHECK_READY;
  CHECK_READY:state<=PARSE;
  PARSE:begin
   // Every byte is consumed exactly once, including boundary-spanning chunks.
   pos<=pos+1'b1;
   if(index==511)begin index<=0;sector_lba<=sector_lba+1'b1;state<=FETCH;resume_state<=FETCH;end
   else begin index<=index+1'b1;state<=ADDR;resume_state<=ADDR;end
   if(!byte_bounds_ok)fail(8'h61);
   else case(RAW_ONLY ? PCM : phase)
    RIFF:begin
     if(pos<4)riff_id[pos[1:0]*8 +:8]<=q;
     else if(pos<8)riff_size[pos[1:0]*8 +:8]<=q;
     else wave_id[pos[1:0]*8 +:8]<=q;
     if(pos==11)begin
      if(!riff_header_ok)fail(8'h62);
      else begin riff_end<=riff_size+8;phase<=CHUNK;field<=0;end
     end
    end
    CHUNK:begin
     if(field<4)chunk_id[field[1:0]*8 +:8]<=q;
     else chunk_size[field[1:0]*8 +:8]<=q;
     field<=field+1'b1;
     if(field==7)begin
      field<=0;left_count<=length_now;
      if(!chunk_bounds_ok)fail(8'h63);
      else if(chunk_id==32'h20746d66)begin
       if(length_now<16 || fmt_ok)fail(8'h64);else phase<=FMT;
      end else if(chunk_id==32'h61746164)begin
       if(!fmt_ok || length_now==0 || length_now[0] || (channels==2 && length_now[1]))fail(8'h65);
       else begin phase<=PCM;component<=0;format_valid<=1;end
      end else if(length_now!=0)begin phase<=SKIP;left_count<=padded_length[31:0];end
      if(pos>65535)fail(8'h66);
     end
    end
    FMT:begin
     left_count<=left_count-1'b1;field<=field+1'b1;
     case(field)
      0:encoding[7:0]<=q;1:encoding[15:8]<=q;
      2:channels[7:0]<=q;3:channels[15:8]<=q;
      4:rate[7:0]<=q;5:rate[15:8]<=q;6:rate[23:16]<=q;7:rate[31:24]<=q;
      8:byte_rate[7:0]<=q;9:byte_rate[15:8]<=q;10:byte_rate[23:16]<=q;11:byte_rate[31:24]<=q;
      12:alignment[7:0]<=q;13:alignment[15:8]<=q;14:bits[7:0]<=q;15:bits[15:8]<=q;
     endcase
     if(field==15)begin
      if(!fmt_header_ok)fail(8'h67);
      else begin
       fmt_ok<=1;field<=0;
       if(left_count==1 && !chunk_size[0])phase<=CHUNK;
       else begin phase<=SKIP;left_count<=left_count-1'b1+chunk_size[0];end
      end
     end
    end
    SKIP:begin left_count<=left_count-1'b1;if(left_count==1)begin phase<=CHUNK;field<=0;end end
    PCM:begin
     left_count<=left_count-1'b1;component<=component+1'b1;
     if(component==0 || component==2)low_byte<=q;
     if(component==1)left_sample<={q,low_byte};
     if((channels==1 && component==1) || component==3)begin
      pcm_data<=channels==1?{q,low_byte,q,low_byte}:{left_sample,q,low_byte};
      pcm_valid<=1;finish_pending<=left_count==1;component<=0;state<=EMIT;
     end
    end
   endcase
  end
  EMIT:if(pcm_ready)begin
   pcm_valid<=0;
   if(finish_pending)begin done<=1;state<=FINISH;end else state<=resume_state;
  end
  FINISH:begin end
  FAIL:begin end
  default:state<=IDLE;
 endcase
end
endmodule
