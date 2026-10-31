`timescale 1ns/1ps
module tb_bmp_timing;
reg clk=0;
always #5 clk=~clk;
reg rst=1, scan_start=0, load_start=0, ack=0, valid=0, sec_end=0;
reg [7:0] data=0;
reg [31:0] max_sector=32'd10000000;
wire scan_done, found_valid, write_req, sec_read;
wire [31:0] found_sector, sec_addr;
wire [2:0] found_total;
bmp_read_legacy dut(.clk(clk), .rst(rst), .ready(),
 .scan_start(scan_start), .scan_start_sector(32'd100),
 .scan_max_sector(max_sector), .scan_target_count(3'd2),
 .scan_done(scan_done), .scan_found_valid(found_valid),
 .scan_found_sector(found_sector), .scan_found_total(found_total),
 .load_start(load_start), .load_sector(32'd100), .sd_init_done(1'b1),
 .state_code(), .bmp_width(16'd640), .bmp_height(16'd480),
 .write_req(write_req), .write_req_ack(ack), .sd_sec_read(sec_read),
 .sd_sec_read_addr(sec_addr), .sd_sec_read_data(data),
 .sd_sec_read_data_valid(valid), .sd_sec_read_end(sec_end),
 .bmp_data_wr_en(), .bmp_data());
task reset_dut;
begin
 @(negedge clk); rst=1; valid=0; sec_end=0; ack=0;
 scan_start=0; load_start=0;
 repeat(3) @(negedge clk);
 rst=0;
 repeat(2) @(negedge clk);
end
endtask
task header;
input [31:0] length;
integer i;
begin
 for(i=0;i<512;i=i+1) begin
  @(negedge clk); valid=1;
  case(i)
   0:data="B"; 1:data="M";
   2:data=length[7:0]; 3:data=length[15:8];
   4:data=length[23:16]; 5:data=length[31:24];
   10:data=54; 18:data=8'h80; 19:data=2;
   22:data=8'he0; 23:data=1; 28:data=24;
   default:data=0;
  endcase
 end
 @(negedge clk); valid=0; sec_end=1;
 @(negedge clk); sec_end=0;
end
endtask
task scan_case;
input [31:0] length, expected_sectors;
begin
 reset_dut;
 scan_start=1;
 @(negedge clk); scan_start=0;
 header(length);
 if(found_total!==1 || found_sector!==100 || sec_addr!==(100+expected_sectors)) begin
  $display("FAIL length=%d next=%d expected=%d",length,sec_addr,100+expected_sectors);
  $fatal(1);
 end
end
endtask
initial begin
 scan_case(0,1);
 scan_case(1,1);
 scan_case(511,1);
 scan_case(512,1);
 scan_case(513,2);
 scan_case(921654,1801);
 scan_case(32'hffffffff,8388608);
 max_sector=100;
 reset_dut; scan_start=1;
 @(negedge clk); scan_start=0;
 header(513);
 if(scan_done!==1) $fatal(1,"Scan maximum boundary was not honored");
 reset_dut; load_start=1;
 @(negedge clk); load_start=0;
 header(921654);
 if(write_req!==1) $fatal(1,"Missing frame write request");
 #2; ack=1;
 @(negedge clk);
 if(write_req!==1) $fatal(1,"ACK bypassed its synchronizer");
 repeat(3) @(negedge clk);
 if(write_req!==0) $fatal(1,"Synchronized ACK did not release request");
 $display("BMP_TIMING_FUNCTIONAL_PASS");
 $finish;
end
initial begin #100000; $fatal(1,"Test timeout"); end
endmodule

