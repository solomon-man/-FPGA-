`timescale 1ns/1ps
module tb_sdram_link;
parameter integer PHASE_NS=0;
reg clk=0;always #6 clk=~clk;
wire shifted;assign #(PHASE_NS) shifted=clk;
reg rst=1;wire done,refresh,busy,rv;wire [31:0] data;
reg we=0,re=0;reg [20:0] wa=0,ra=0;reg [31:0] wd=0;
integer sent=0,received=0,n;reg checking=0;
sdram dut(.Clk(clk),.Clk_sft(shifted),.Rst(rst),.Sdr_init_done(done),.Sdr_init_ref_vld(refresh),.Sdr_busy(busy),
 .App_wr_en(we),.App_wr_addr(wa),.App_wr_dm(4'd0),.App_wr_din(wd),.App_rd_en(re),.App_rd_addr(ra),.Sdr_rd_en(rv),.Sdr_rd_dout(data));
always @(posedge clk)if(checking && rv)begin
 if(data!==(32'h4ca70000+received))$fatal(1,"SDRAM LINK phase=%d read=%d expected=%h got=%h",PHASE_NS,received,32'h4ca70000+received,data);
 received=received+1;
end
initial begin
 repeat(5)@(negedge clk);rst=0;wait(done);repeat(30)@(negedge clk);
 // Cross column, bank and row boundaries at real RGB888 addresses.
 for(n=0;n<2048;n=n+1)begin
  @(negedge clk);if(n%128==0)while(busy || refresh)begin we=0;@(negedge clk);end
  we=1;wa=1228800+n;wd=32'h4ca70000+n;
 end
 @(negedge clk);we=0;repeat(40)@(negedge clk);checking=1;
 for(n=0;n<2048;n=n+1)begin
  @(negedge clk);if(n%128==0)while(busy || refresh)begin re=0;@(negedge clk);end
  re=1;ra=1228800+n;
 end
 @(negedge clk);re=0;repeat(50)@(negedge clk);
 if(received!=2048)$fatal(1,"SDRAM read count %d",received);
 $display("SDRAM_REAL_CONTROLLER_RGB888_PHASE_%0d_ROWBANK_READWRITE_PASS",PHASE_NS);$finish;
end
initial begin #3000000;$fatal(1,"timeout");end
endmodule

// Behavioral SDR SDRAM: sequential burst, bank/row, CAS and 6ns tAC.
// A protocol model only; it does not replace routed setup/hold analysis.
module EG_PHY_SDRAM_2M_32(input clk,ras_n,cas_n,we_n,input [10:0] addr,input [1:0] ba,
 inout [31:0] dq,input cs_n,dm0,dm1,dm2,dm3,cke);
reg [31:0] memory[0:2097151];reg [10:0] row[0:3];reg [3:0] active=0;
reg [31:0] rd[0:3];reg [3:0] valid=0;integer cas_latency=3,i;
reg [31:0] dq_value=0;reg dq_enable=0;
reg reading=0,writing=0;reg [1:0] burst_bank=0;reg [7:0] column=0,start_col=0;
integer burst_length=1,beat=0,index;
wire [2:0] command={ras_n,cas_n,we_n};
assign dq=dq_enable?dq_value:32'bz;
always @(posedge clk)if(cke && !cs_n)begin
 for(i=3;i>0;i=i-1)begin rd[i]=rd[i-1];valid[i]=valid[i-1];end
 valid[0]=0;
 case(command)
 3'b000:begin
  cas_latency=addr[6:4];burst_length=addr[2:0]==7?256:1<<addr[2:0];
  if(addr[3])$fatal(1,"interleaved SDR burst unsupported");
  $display("SDRAM MRS %h CAS %d BL %d",addr,cas_latency,burst_length);
 end
 3'b011:begin row[ba]=addr;active[ba]=1;end
 3'b010:begin
  if(addr[10])active=0;else active[ba]=0;
  reading=0;writing=0;
 end
 3'b110:begin reading=0;writing=0;end
 3'b101,3'b100:begin
  if(!active[ba])$fatal(1,"READ/WRITE without ACT");
  reading=command==3'b101;writing=command==3'b100;
  burst_bank=ba;start_col=addr[7:0];column=addr[7:0];beat=0;
 end
 endcase
 if(reading)begin
  rd[0]=memory[{row[burst_bank],column[7:2],burst_bank,column[1:0]}];valid[0]=1;
 end
 if(writing)begin
  index={row[burst_bank],column[7:2],burst_bank,column[1:0]};
  if(!dm0)memory[index][7:0]=dq[7:0];
  if(!dm1)memory[index][15:8]=dq[15:8];
  if(!dm2)memory[index][23:16]=dq[23:16];
  if(!dm3)memory[index][31:24]=dq[31:24];
 end
 if(reading || writing)begin
  beat=beat+1;column=(start_col & ~(burst_length-1)) | ((start_col+beat)&(burst_length-1));
  if(beat==burst_length)begin reading=0;writing=0;end
 end
 dq_enable<=#6 valid[cas_latency-1];dq_value<=#6 rd[cas_latency-1];
end
endmodule
