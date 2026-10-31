`timescale 1ns/1ps
module tb_sd_audio #(parameter PARTITION=0,PCM_ONLY=0,LOOP_TEST=0);
reg clk=0,pclk=0;always #5 clk=~clk;always #20 pclk=~pclk;
reg rst=1,allow=0,play=0;reg [2:0] track=0;wire [2:0] count,status;wire [7:0] error;
wire req,player_req,player_valid,player_end,bus_idle;wire [31:0] lba,player_lba;reg [7:0] data=0;reg valid=0,done=0;
wire [23:0] left,right;reg tick=0;integer cadence=0;
always @(negedge pclk)begin
 if(rst)begin cadence=0;tick=0;end
 else begin tick=cadence==99;cadence=cadence==99?0:cadence+1;end
end
reg [7:0] disk[0:327679];reg [7:0] mbr[0:511];integer z;integer ix,offset,received=0,expected_samples=0,check_track=0;
integer lv,rv,requests=0;reg serving=0,checking=0;
reg raw_check=0;
sd_wav_player #(.ENABLE_WAV(!PCM_ONLY),.LOOP_PLAYBACK(LOOP_TEST)) dut(.clk(clk),.rst(rst),.allow(allow),.sd_ready(1'b1),.bus_idle(bus_idle),.track(track),.play(play),
 .track_count(count),.status(status),.error_code(error),.sector_req(player_req),.sector_lba(player_lba),.sector_data(data),.sector_valid(player_valid),.sector_end(player_end),
 .pixel_clk(pclk),.pixel_rst(rst),.audio_tick(tick),.play_pixel(play && track!=0),.left_pcm(left),.right_pcm(right));
sd_read_arbiter arb(.clk(clk),.rst(rst),.a_req(1'b0),.a_lba(32'd0),.b_req(player_req),.b_lba(player_lba),
 .card_valid(valid),.card_end(done),.a_valid(),.a_end(),.b_valid(player_valid),.b_end(player_end),
 .card_req(req),.card_lba(lba),.idle(bus_idle),.timeout());
always @(posedge pclk)if(!rst && tick && dut.read_take && checking)begin
 if(raw_check)begin lv=(received%expected_samples)*73%60000-30000;rv=lv;end
 else if(check_track==2)begin lv=received%2?-1000-received:1000+received;rv=lv;end
 else begin lv=(received*271%50000)-25000;rv=(received*613%40000)-20000;end
 if(left!=={lv[15:0],8'd0} || right!=={rv[15:0],8'd0})$fatal(1,"PCM mismatch n%0d L%h R%h want %h %h",received,left,right,lv[15:0],rv[15:0]);
 received=received+1;
 if(!LOOP_TEST && received>expected_samples)$fatal(1,"Read beyond data length");
end
initial begin
 $readmemh("wav_disk.hex",disk);
 for(z=0;z<512;z=z+1)mbr[z]=0;
 mbr[450]=8'h0c;mbr[454]=PARTITION&255;mbr[455]=(PARTITION>>8)&255;
 mbr[456]=(PARTITION>>16)&255;mbr[457]=(PARTITION>>24)&255;mbr[510]=8'h55;mbr[511]=8'haa;
 forever begin
  wait(req);serving=1;offset=(lba-PARTITION)*512;requests=requests+1;
  if(lba>=640+PARTITION)$fatal(1,"Out-of-bounds SD %d",lba);
  repeat(10)@(negedge clk);
  for(ix=0;ix<512;ix=ix+1)begin
   @(negedge clk);data=(PARTITION!=0 && lba==0)?mbr[ix]:disk[offset+ix];valid=1;
   @(negedge clk);valid=0;repeat(2)@(negedge clk);
  end
  @(negedge clk);done=1;@(negedge clk);done=0;
  wait(!req);repeat(6)@(negedge clk);serving=0;
 end
end
task stop;begin
 play=0;checking=0;repeat(100)@(negedge clk);wait(dut.state==2);
 repeat(20)@(negedge pclk);
 if(status!=0 || left!=0 || right!=0 || dut.read_take)
  $fatal(1,"Stopped player did not become silent/idle");
end endtask
task run_track;input integer t,n;begin
 track=t;received=0;expected_samples=n;check_track=t;checking=1;play=1;
 if(LOOP_TEST)wait(received==n*3 || status==4);
 else wait(status==3 || status==4);
 if(status==4)$fatal(1,"WAV track %d failed %h",t,error);
 repeat(10)@(negedge pclk);
 if(received!=(LOOP_TEST?n*3:n))$fatal(1,"PCM count %d wanted %d",received,n);
 stop;
end endtask
initial begin
 repeat(5)@(negedge clk);rst=0;
 repeat(20)@(negedge clk);if(req)$fatal(1,"Stole bus during pictures");
 allow=1;wait(dut.state==2);
 if(!PCM_ONLY)begin
 if(count!=4)$fatal(1,"Directory count %d",count);
 run_track(1,700);$display("WAV_FRAGMENTED_STEREO_CHUNKS_PADDING_EXACT_PCM_PASS");
 run_track(2,13);$display("WAV_SHORT_MONO_PREFILL_EOF_PASS");
 track=3;play=1;wait(status==4);if(error!=8'h67)$fatal(1,"Unsupported rate %h",error);
 if(left!=0 || right!=0)$fatal(1,"Unsupported file audio");stop;
 track=1;play=1;wait(dut.read_active);repeat(3)@(negedge pclk);
 track=2;checking=0;wait(dut.fifo_reset);wait(dut.state==7);received=0;expected_samples=13;check_track=2;checking=1;
 wait(status==3 || status==4);if(status!=3 || received!=13)$fatal(1,"Switch flush");stop;
 disk[512+44]=8'hff;disk[512+45]=8'hff;disk[512+46]=8'hff;disk[512+47]=8'h0f;
 track=4;play=1;wait(status==4);if(error!=8'h56)$fatal(1,"Broken chain %h",error);stop;
 // Reject malformed chunk bounds and PCM alignment before playback.
 disk[607*512+40]=8'hff;disk[607*512+41]=8'hff;
 track=2;play=1;wait(status==4);if(error!=8'h63)$fatal(1,"Oversized data chunk %h",error);stop;
 disk[607*512+40]=26;disk[607*512+41]=0;disk[607*512+32]=4;
 track=2;play=1;wait(status==4);if(error!=8'h67)$fatal(1,"Invalid alignment %h",error);stop;
 $display("WAV_BOUNDS_ALIGNMENT_REJECT_PASS PARTITION=%0d",PARTITION);
 $display("SD_AUDIO_CATALOG_INVALID_RATE_SWITCH_FLUSH_BAD_CHAIN_PASS");
 end else if(count!=0)$fatal(1,"PCM-only catalog accepted WAV");
 // Remount a mixed WAV/PCM directory. Raw PCM has no RIFF header.
 rst=1;repeat(10)@(negedge clk);
 disk[601*512+160+8]="p";disk[601*512+160+9]="c";disk[601*512+160+10]="m";
 disk[601*512+160+28]=1400&255;disk[601*512+160+29]=1400>>8;
 disk[512+8*4]=14;disk[512+8*4+1]=0;disk[512+8*4+2]=0;disk[512+8*4+3]=0;
 disk[512+14*4]=15;disk[512+14*4+1]=0;disk[512+14*4+2]=0;disk[512+14*4+3]=0;
 disk[512+15*4]=255;disk[512+15*4+1]=255;disk[512+15*4+2]=255;disk[512+15*4+3]=15;
 for(z=0;z<700;z=z+1)begin
  offset=z*2;ix=offset<512?607*512+offset:(offset<1024?613*512+offset-512:614*512+offset-1024);
  lv=z*73%60000-30000;disk[ix]=lv&255;disk[ix+1]=(lv>>8)&255;
 end
 rst=0;wait(dut.state==2);if(count!=(PCM_ONLY?1:4))$fatal(1,"Mixed directory count");
 raw_check=1;run_track(PCM_ONLY?1:2,700);raw_check=0;
 if(!PCM_ONLY)run_track(1,700);
 if(LOOP_TEST)$display("SD_PCM_THREE_LOOPS_EXACT_SAMPLES_STOP_PASS");
 $display("RAW_PCM_FRAGMENTED_MONO_EXACT_SAMPLES_WAV_SWITCH_PASS PARTITION=%0d",PARTITION);
 // A one-sample PCM file is valid, while an odd byte count is rejected.
 rst=1;repeat(10)@(negedge clk);
 disk[601*512+160+28]=2;disk[601*512+160+29]=0;
 disk[512+8*4]=255;disk[512+8*4+1]=255;disk[512+8*4+2]=255;disk[512+8*4+3]=15;
 rst=0;wait(dut.state==2);raw_check=1;run_track(PCM_ONLY?1:2,1);raw_check=0;
 rst=1;repeat(10)@(negedge clk);disk[601*512+160+28]=3;rst=0;wait(dut.state==2);
 track=PCM_ONLY?1:2;play=1;wait(status==4);if(error!=8'h65)$fatal(1,"Odd raw PCM size accepted");stop;
 $display("RAW_PCM_SHORT_EOF_ODD_LENGTH_REJECT_PASS");
 if(PCM_ONLY)$display("PCM_ONLY_BUILD_CATALOG_FRAGMENTED_PLAYBACK_PASS");$finish;
end
initial begin #30000000;$fatal(1,"Timeout state%d decoder%d status%d error%h",dut.state,dut.decoder.state,status,error);end
endmodule
