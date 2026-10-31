// Read-only FAT32 metadata and virtual WAV/raw-PCM sector translation.
// Course 7: BPB -> root directory -> FAT cluster chain, original SPI retained.
module fat32_wav_map #(parameter integer INCLUDE_WAV=1)(
 input clk,rst,abort_load,sd_ready,input mount_start,
 output reg mount_done,found_valid,output reg [31:0] found_token,
 output reg [2:0] found_count,output reg [1:0] fat_status,
 input load_start,input [1:0] file_index,
 input virtual_req,input [31:0] virtual_lba,
 output [7:0] virtual_data,output virtual_valid,output reg virtual_end,
 output reg load_error,output reg [7:0] fs_error,
 output reg sector_req,output reg [31:0] sector_lba,
 input [7:0] sector_data,input sector_valid,sector_done,output [31:0] file_bytes,
 output reg raw_pcm);
localparam [24:0] IDLE=23'b1<<0,READ=23'b1<<1,WAIT=23'b1<<2,PARSE0=23'b1<<3,
 BPB=23'b1<<4,LAYOUT=23'b1<<5,ROOT=23'b1<<6,DIR_END=23'b1<<7,
 ROOT_NEXT=23'b1<<8,FAT_ROOT=23'b1<<9,READY=23'b1<<10,MAP=23'b1<<11,
 SHIFT=23'b1<<12,BASE=23'b1<<13,OFFSET=23'b1<<14,DATA=23'b1<<15,
 DATA_END=23'b1<<16,FAT_FILE=23'b1<<17,COMPLETE=23'b1<<18,FAIL=23'b1<<19,
 GEOMETRY=23'b1<<20,BOUNDS=23'b1<<21,CHECK=23'b1<<22,
 MAP_PREP=25'b1<<23,BOOT_SETTLE=25'b1<<24;
reg [24:0] state,return_state;
reg [8:0] byte_index;
reg boot_meta,dir_meta,fat_meta,file_meta;
reg [15:0] signature,bps,reserved,root_entries,fat16,flags,version;
reg [7:0] spc,nfats,ptype,entry_first,entry_attr,e0,e1,e2;
reg [31:0] fat_size,total,root_cluster,partition,part_candidate,part_lba;
reg [31:0] fat_base,data_base,max_cluster,cluster_count,volume_end;
reg [31:0] clusters[0:3],sizes[0:3];
reg raw_types[0:3];
reg is_wav,is_pcm;
reg [31:0] entry_cluster,entry_size,current_cluster,next_cluster;
reg [31:0] cluster_offset,mapped_sector,requested_sector,file_size,bmp_size;
reg [7:0] in_cluster;
assign file_bytes=file_size;
reg [2:0] spc_shift;
reg [16:0] chain_steps;
reg dir_finished,final_check;
reg [1:0] cooldown;
reg [31:0] watchdog;
wire [8:0] fat_offset={current_cluster[6:0],2'b00};
reg [31:0] file_sectors,cluster_slots;
reg valid_cluster,geometry_ok,bmp_length_ok,last_file_sector,sequential_sector;
// Registered boot, directory and mapping decisions. BOOT_SETTLE follows every
// boot-sector read; MAP_PREP settles map_* before MAP consumes them.
reg boot_signature_ok,boot_geometry_ok,bpb_invalid;
reg entry_ok,entry_size_ok,cluster_end,cluster_more,root_chain_limit,file_chain_limit;
reg map_beyond,map_first,map_same;
// Registered layout operands (3.0 timing): FAT span is settled before LAYOUT,
// volume span one cycle after data_base; GEOMETRY waits for it via cooldown.
reg [31:0] fat_span,volume_span;
always @(posedge clk or posedge rst)begin
 if(rst)begin file_sectors<=0;cluster_slots<=0;valid_cluster<=0;geometry_ok<=0;
  bmp_length_ok<=0;last_file_sector<=0;sequential_sector<=0;is_wav<=0;is_pcm<=0;
  boot_signature_ok<=0;boot_geometry_ok<=0;bpb_invalid<=1;
  entry_ok<=0;entry_size_ok<=0;cluster_end<=0;cluster_more<=0;root_chain_limit<=0;file_chain_limit<=0;
  map_beyond<=0;map_first<=0;map_same<=0;fat_span<=0;volume_span<=0;
 end else begin
  fat_span<=nfats==2?(fat_size<<1):fat_size;
  volume_span<=volume_end-data_base;
  boot_signature_ok<=signature==16'haa55;
  boot_geometry_ok<=bps==512 && root_entries==0 && fat16==0;
  bpb_invalid<=bps!=512 || root_entries!=0 || fat16!=0 ||
     spc==0 || spc>128 || (spc&(spc-1'b1))!=0 || reserved==0 ||
     nfats==0 || nfats>2 || fat_size==0 || fat_size>=32'h01000000 ||
     root_cluster<2 || version!=0 || (flags[7] && flags[3:0]>=nfats);
  // is_wav/is_pcm settle from offset 10; the cluster bytes end at offset 27.
  entry_ok<=found_count<4 && entry_first!=8'he5 && entry_attr!=8'h0f &&
   (entry_attr&8'h18)==0 && ((INCLUDE_WAV && is_wav) || is_pcm) &&
   entry_cluster>=2 && entry_cluster<=max_cluster;
  entry_size_ok<=is_pcm?entry_size[23:0]>=24'd2:entry_size[23:0]>=24'd44;
  cluster_end<=next_cluster>=32'h0ffffff8;
  cluster_more<=in_cluster+1'b1<spc;
  root_chain_limit<=chain_steps>=255;
  file_chain_limit<=chain_steps>=131071;
  map_beyond<=requested_sector>=file_sectors;
  map_first<=requested_sector==0;
  map_same<=requested_sector==mapped_sector;
  // Extension bytes finish at entry offset 10, well before commit at offset 31.
  is_wav<=(e0&8'hdf)=="W" && (e1&8'hdf)=="A" && (e2&8'hdf)=="V";
  is_pcm<=(e0&8'hdf)=="P" && (e1&8'hdf)=="C" && (e2&8'hdf)=="M";
  file_sectors<={9'd0,file_size[31:9]}+{31'd0,|file_size[8:0]};
  valid_cluster<=next_cluster>=2 && next_cluster<=max_cluster && next_cluster!=current_cluster;
  cluster_slots<=cluster_count+2;
  geometry_ok<=volume_end>=partition && volume_end>data_base && cluster_count!=0 &&
    cluster_count<32'h0ffffff5 && cluster_slots<=(fat_size<<7) && root_cluster<=max_cluster;
  bmp_length_ok<=bmp_size==file_size;
  last_file_sector<=requested_sector+1'b1==file_sectors;
  sequential_sector<=requested_sector==mapped_sector+1'b1;
 end
end
assign virtual_data=sector_data;
assign virtual_valid=state[2] && file_meta && sector_valid;
task read_block;
 input [31:0] address;input [24:0] destination;
 begin sector_lba<=address;return_state<=destination;state<=READ;end
endtask
task fail;
 input [7:0] code;
 begin fs_error<=code;sector_req<=0;
  if(fat_status==2)begin load_error<=1;state<=READY;end
  else begin fat_status<=3;mount_done<=1;state<=FAIL;end
 end
endtask
integer k;
always @(posedge clk or posedge rst)begin
 if(rst)begin
  state<=IDLE;return_state<=0;byte_index<=0;mount_done<=0;found_valid<=0;
  found_token<=0;found_count<=0;fat_status<=0;virtual_end<=0;load_error<=0;fs_error<=0;
  sector_req<=0;sector_lba<=0;boot_meta<=0;dir_meta<=0;fat_meta<=0;file_meta<=0;
  signature<=0;bps<=0;reserved<=0;root_entries<=0;fat16<=0;flags<=0;version<=0;
  spc<=0;nfats<=0;ptype<=0;fat_size<=0;total<=0;root_cluster<=0;partition<=0;
  part_candidate<=0;part_lba<=0;fat_base<=0;data_base<=0;max_cluster<=0;volume_end<=0;cluster_count<=0;
  entry_first<=0;entry_attr<=0;e0<=0;e1<=0;e2<=0;entry_cluster<=0;entry_size<=0;
  current_cluster<=0;next_cluster<=0;cluster_offset<=0;mapped_sector<=0;requested_sector<=0;
  file_size<=0;bmp_size<=0;in_cluster<=0;spc_shift<=0;chain_steps<=0;
  dir_finished<=0;final_check<=0;cooldown<=0;watchdog<=0;
  raw_pcm<=0;
  for(k=0;k<4;k=k+1)begin clusters[k]<=0;sizes[k]<=0;raw_types[k]<=0;end
 end else begin
  found_valid<=0;virtual_end<=0;load_error<=0;
  if(state[2])begin
   watchdog<=watchdog+1'b1;
   if(watchdog==100_000_000)fail(8'h51);
  end else watchdog<=0;
  if(sector_valid && state[2])begin
   byte_index<=byte_index+1'b1;
   if(boot_meta)begin
    case(byte_index)
     11:bps[7:0]<=sector_data;12:bps[15:8]<=sector_data;13:spc<=sector_data;
     14:reserved[7:0]<=sector_data;15:reserved[15:8]<=sector_data;16:nfats<=sector_data;
     17:root_entries[7:0]<=sector_data;18:root_entries[15:8]<=sector_data;
     22:fat16[7:0]<=sector_data;23:fat16[15:8]<=sector_data;
     32:total[7:0]<=sector_data;33:total[15:8]<=sector_data;
     34:total[23:16]<=sector_data;35:total[31:24]<=sector_data;
     36:fat_size[7:0]<=sector_data;37:fat_size[15:8]<=sector_data;
     38:fat_size[23:16]<=sector_data;39:fat_size[31:24]<=sector_data;
     40:flags[7:0]<=sector_data;41:flags[15:8]<=sector_data;
     42:version[7:0]<=sector_data;43:version[15:8]<=sector_data;
     44:root_cluster[7:0]<=sector_data;45:root_cluster[15:8]<=sector_data;
     46:root_cluster[23:16]<=sector_data;47:root_cluster[31:24]<=sector_data;
     510:signature[7:0]<=sector_data;511:signature[15:8]<=sector_data;
    endcase
    if(byte_index>=446 && byte_index<510)case(byte_index[3:0])
     2:ptype<=sector_data;
     6:part_candidate[7:0]<=sector_data;7:part_candidate[15:8]<=sector_data;
     8:part_candidate[23:16]<=sector_data;
     9:if((ptype==8'h0b || ptype==8'h0c) && part_lba==0)
        part_lba<={sector_data,part_candidate[23:0]};
    endcase
   end
   if(fat_meta && byte_index[8:2]==fat_offset[8:2])case(byte_index[1:0])
    0:next_cluster[7:0]<=sector_data;1:next_cluster[15:8]<=sector_data;
    2:next_cluster[23:16]<=sector_data;3:next_cluster[31:24]<={4'd0,sector_data[3:0]};
   endcase
   if(dir_meta && !dir_finished)case(byte_index[4:0])
    0:begin entry_first<=sector_data;if(sector_data==0)dir_finished<=1;end
    8:e0<=sector_data;9:e1<=sector_data;10:e2<=sector_data;11:entry_attr<=sector_data;
    20:entry_cluster[23:16]<=sector_data;21:entry_cluster[31:24]<=sector_data;
    26:entry_cluster[7:0]<=sector_data;27:entry_cluster[15:8]<=sector_data;
    28:entry_size[7:0]<=sector_data;29:entry_size[15:8]<=sector_data;30:entry_size[23:16]<=sector_data;
    31:if(entry_ok && (sector_data!=0 || entry_size_ok))begin
       clusters[found_count[1:0]]<=entry_cluster;
       sizes[found_count[1:0]]<={sector_data,entry_size[23:0]};
       raw_types[found_count[1:0]]<=is_pcm;
       found_token<={29'd0,found_count};found_valid<=1;found_count<=found_count+1'b1;
      end
   endcase
   if(file_meta && requested_sector==0)case(byte_index)
    2:bmp_size[7:0]<=sector_data;3:bmp_size[15:8]<=sector_data;
    4:bmp_size[23:16]<=sector_data;5:bmp_size[31:24]<=sector_data;
   endcase
  end
  // Explicit one-hot decode avoids a priority chain on shared control enables.
  case(1'b1) // synthesis parallel_case
   state[0]:if(mount_start && sd_ready)read_block(0,PARSE0);
   state[1]:if(sd_ready)begin
    boot_meta<=return_state[3] || return_state[4];
    dir_meta<=return_state[7];fat_meta<=return_state[9] || return_state[17];
    file_meta<=return_state[16];byte_index<=0;sector_req<=1;state<=WAIT;
   end
   state[2]:if(sector_done)begin sector_req<=0;state<=boot_meta?BOOT_SETTLE:return_state;end
   state[24]:state<=return_state;
   state[3]:if(boot_signature_ok && boot_geometry_ok)begin
     partition<=0;state<=BPB;
    end else if(boot_signature_ok && part_lba!=0)begin partition<=part_lba;read_block(part_lba,BPB);end
    else begin fat_status<=1;mount_done<=1;state<=READY;end
   state[4]:if(!boot_signature_ok || bpb_invalid)fail(8'h52);
    else begin
     case(spc)1:spc_shift<=0;2:spc_shift<=1;4:spc_shift<=2;8:spc_shift<=3;
      16:spc_shift<=4;32:spc_shift<=5;64:spc_shift<=6;128:spc_shift<=7;endcase
     fat_base<=partition+reserved;volume_end<=partition+total;state<=LAYOUT;
    end
   state[5]:begin
    data_base<=fat_base+fat_span;cooldown<=1;
    if(flags[7] && flags[3:0]==1)fat_base<=fat_base+fat_size;
    state<=GEOMETRY;
   end
   state[20]:if(cooldown!=0)cooldown<=cooldown-1'b1;
    else begin cluster_count<=volume_span>>spc_shift;state<=BOUNDS;end
   state[21]:begin max_cluster<=cluster_count+1;cooldown<=3;state<=CHECK;end
   state[22]:if(cooldown!=0)cooldown<=cooldown-1'b1;
    else if(!geometry_ok)fail(8'h52);
    else begin current_cluster<=root_cluster;in_cluster<=0;chain_steps<=0;state<=ROOT;end
   state[6]:begin cluster_offset<=current_cluster-2;return_state<=DIR_END;state<=SHIFT;end
   state[12]:begin cluster_offset<=cluster_offset<<spc_shift;state<=BASE;end
   state[13]:begin sector_lba<=data_base+cluster_offset;state<=OFFSET;end
   state[14]:begin sector_lba<=sector_lba+in_cluster;state<=READ;end
   state[7]:if(dir_finished || found_count==4)begin fat_status<=2;mount_done<=1;state<=READY;end
    else state<=ROOT_NEXT;
   state[8]:if(cluster_more)begin in_cluster<=in_cluster+1'b1;state<=ROOT;end
    else begin in_cluster<=0;read_block(fat_base+(current_cluster>>7),FAT_ROOT);end
   state[9]:if(cluster_end)begin fat_status<=2;mount_done<=1;state<=READY;end
    else if(!valid_cluster || root_chain_limit)fail(8'h53);
    else begin current_cluster<=next_cluster;chain_steps<=chain_steps+1'b1;state<=ROOT;end
   state[10]:if(load_start && fat_status==2)begin
     current_cluster<=clusters[file_index];file_size<=sizes[file_index];
     raw_pcm<=raw_types[file_index];
     mapped_sector<=0;in_cluster<=0;chain_steps<=0;fs_error<=0;
    end else if(virtual_req && fat_status==2 && !abort_load)begin requested_sector<=virtual_lba;state<=MAP_PREP;end
   state[23]:state<=MAP;
   state[11]:if(map_beyond)fail(8'h54);
    else if(map_first)begin current_cluster<=clusters[file_index];in_cluster<=0;
     mapped_sector<=0;chain_steps<=0;state<=DATA;end
    else if(map_same)state<=DATA;
    else if(sequential_sector)begin
     mapped_sector<=requested_sector;
     if(cluster_more)begin in_cluster<=in_cluster+1'b1;state<=DATA;end
     else begin in_cluster<=0;final_check<=0;read_block(fat_base+(current_cluster>>7),FAT_FILE);end
    end else fail(8'h54);
   state[15]:begin cluster_offset<=current_cluster-2;return_state<=DATA_END;state<=SHIFT;end
   state[16]:if(last_file_sector)begin
     final_check<=1;read_block(fat_base+(current_cluster>>7),FAT_FILE);
    end else begin virtual_end<=1;cooldown<=3;state<=COMPLETE;end
   state[17]:if(final_check)begin
     final_check<=0;
     if(cluster_end)begin virtual_end<=1;cooldown<=3;state<=COMPLETE;end
     else fail(8'h56);
    end else if(!valid_cluster || file_chain_limit)fail(8'h56);
    else begin current_cluster<=next_cluster;chain_steps<=chain_steps+1'b1;state<=DATA;end
   state[18]:if(cooldown!=0)cooldown<=cooldown-1'b1;else state<=READY;
   state[19]:begin end
  endcase
  if(abort_load && fat_status==2)begin sector_req<=0;state<=READY;load_error<=0;end
 end
end
endmodule

