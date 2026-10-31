from pathlib import Path
b=Path(r'G:\ANLU_Project\digital photo frame3.0\build')
(b/'tb_sdram_link.v').write_text('''`timescale 1ns/1ps
module tb_sdram_link;
parameter integer PHASE_NS=4;
reg clk=0;always #5 clk=~clk;
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
  @(negedge clk);while(busy || refresh)@(negedge clk);
  we=1;wa=1228800+n;wd=32'h4ca70000+n;
 end
 @(negedge clk);we=0;repeat(40)@(negedge clk);checking=1;
 for(n=0;n<2048;n=n+1)begin
  @(negedge clk);while(busy || refresh)begin re=0;@(negedge clk);end
  re=1;ra=1228800+n;
 end
 @(negedge clk);re=0;repeat(50)@(negedge clk);
 if(received!=2048)$fatal(1,"SDRAM read count %d",received);
 $display("SDRAM_REAL_CONTROLLER_RGB888_PHASE_%0d_ROWBANK_READWRITE_PASS",PHASE_NS);$finish;
end
initial begin #3000000;$fatal(1,"timeout");end
endmodule

// Behavioral SDR SDRAM: BL1, bank/row activation, programmable CAS and 6ns tAC.
// This checks protocol/word alignment; routed STA separately checks physical IO.
module EG_PHY_SDRAM_2M_32(input clk,ras_n,cas_n,we_n,input [10:0] addr,input [1:0] ba,
 inout [31:0] dq,input cs_n,dm0,dm1,dm2,dm3,cke);
reg [31:0] memory[0:2097151];reg [10:0] row[0:3];reg [3:0] active=0;
reg [31:0] rd[0:3];reg [3:0] valid=0;integer cas_latency=3,i;
reg [31:0] dq_value=0;reg dq_enable=0;
assign dq=dq_enable?dq_value:32'bz;
always @(posedge clk)if(cke && !cs_n)begin
 for(i=3;i>0;i=i-1)begin rd[i]=rd[i-1];valid[i]=valid[i-1];end
 valid[0]=0;
 case({ras_n,cas_n,we_n})
 3'b000:begin cas_latency=addr[6:4];if(addr[2:0]!=0)$fatal(1,"model requires BL1");end
 3'b011:begin row[ba]=addr;active[ba]=1;end
 3'b010:begin if(addr[10])active=0;else active[ba]=0;end
 3'b101:begin
  if(!active[ba])$fatal(1,"READ without ACT");
  rd[0]=memory[{row[ba],ba,addr[7:0]}];valid[0]=1;
 end
 3'b100:begin
  if(!active[ba])$fatal(1,"WRITE without ACT");
  if(!dm0)memory[{row[ba],ba,addr[7:0]}][7:0]=dq[7:0];
  if(!dm1)memory[{row[ba],ba,addr[7:0]}][15:8]=dq[15:8];
  if(!dm2)memory[{row[ba],ba,addr[7:0]}][23:16]=dq[23:16];
  if(!dm3)memory[{row[ba],ba,addr[7:0]}][31:24]=dq[31:24];
 end
 endcase
 dq_enable<=#6 valid[cas_latency-1];dq_value<=#6 rd[cas_latency-1];
end
endmodule
''')
(b/'test_sdram_link.do').write_text('''onerror {quit -code 1 -force}
vlib work_sdram_link
vlog -sv -work work_sdram_link +incdir+../user_source/hdl_source/include ../user_source/hdl_source/include/sdr_init_ref.enc.v ../user_source/hdl_source/include/sdr_wrrd.enc.v ../user_source/hdl_source/include/sdr_as_ram.enc.v ../user_source/hdl_source/SD/sdram.v tb_sdram_link.v
vsim -novopt work_sdram_link.tb_sdram_link
onfinish stop
run -all
quit -code 0 -force
''')
