`timescale 1ns/1ps
module tb_raw_pcm #(parameter CHANNELS=1);
reg clk=0;always #5 clk=~clk;
reg rst=1,start=0,valid=0,sector_end=0,ready=0;
reg [7:0] data=0;wire req,pcm_valid,done,error,format_valid;
wire [31:0] lba,pcm;wire [7:0] error_code;
reg [7:0] bytes[0:4095];integer i,n=0,base,pace=0;
reg [15:0] expected_left,expected_right;
wav_pcm_reader #(.RAW_PCM_CHANNELS(CHANNELS)) dut(
 .clk(clk),.rst(rst),.start(start),.file_bytes(32'd4096),.raw_pcm(1'b1),
 .sector_req(req),.sector_lba(lba),.sector_data(data),.sector_valid(valid),.sector_end(sector_end),
 .pcm_data(pcm),.pcm_valid(pcm_valid),.pcm_ready(ready),
 .format_valid(format_valid),.done(done),.error(error),.error_code(error_code));
always @(negedge clk)begin pace=pace+1;ready=pace%17<8;end
always @(posedge clk)if(!rst && pcm_valid && ready)begin
 base=n*CHANNELS*2;expected_left={bytes[base+1],bytes[base]};
 expected_right=CHANNELS==1?expected_left:{bytes[base+3],bytes[base+2]};
 if((^pcm)===1'bx || pcm!=={expected_left,expected_right})$fatal(1,"BGM prefix mismatch/unknown sample %0d",n);
 n=n+1;
end
initial begin
 $readmemh("bgm_prefix.hex",bytes);
 for(i=0;i<4096;i=i+1)if((^bytes[i])===1'bx)$fatal(1,"Missing/incomplete bgm_prefix.hex at byte %0d",i);
 forever begin
  wait(req);if(lba>7)$fatal(1,"Read beyond PCM prefix");
  for(i=0;i<512;i=i+1)begin
   @(negedge clk);valid=1;data=bytes[lba*512+i];
   @(negedge clk);valid=0;
  end
  @(negedge clk);sector_end=1;@(negedge clk);sector_end=0;wait(!req);
 end
end
initial begin
 repeat(5)@(negedge clk);rst=0;start=1;@(negedge clk);start=0;
 wait(done || error);#1;
 if(error || !format_valid || n!=4096/(CHANNELS*2))$fatal(1,"BGM decode failed %h count%0d",error_code,n);
 $display("REAL_BGM_PCM_PREFIX_EXACT_SAMPLES_BACKPRESSURE_PASS CHANNELS=%0d",CHANNELS);$finish;
end
initial begin #2000000;$fatal(1,"PCM prefix timeout");end
endmodule
