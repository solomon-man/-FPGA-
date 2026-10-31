`timescale 1ns/1ps
module tb_serial_reset;
reg p=0,s=0,raw=1;always #7.692 p=~p;always #1.5384 s=~s;
wire rp,rs,q,refq;reg [9:0] data=10'h155;integer n;
reset_release pixel(p,raw,rp);reset_release serial(s,raw,rs);
lane_lvds_10_1 dut(.I_pixel_clk(p),.I_serial_clk(s),.I_rst(rp),.I_serial_rst(rs),.I_data_in(data),.O_serial_out(q));
lane_reference old(.I_pixel_clk(p),.I_serial_clk(s),.I_rst(rp),.I_data_in(data),.O_serial_out(refq));
always @(negedge p)if(!rp)data<={data[8:0],data[9]^data[6]};
initial begin
 #101 raw=0;wait(!rp);#200;
 for(n=0;n<2000;n=n+1)begin @(negedge s);#0.2;if(q!==refq || ^q===1'bx)$fatal(1,"serializer mismatch");end
 #0.73 raw=1;#1;if(rp!==1 || rs!==1)$fatal(1,"async reset assertion");
 #71 raw=0;wait(!rp);#200;
 for(n=0;n<2000;n=n+1)begin @(posedge s);#0.2;if(q!==refq || ^q===1'bx)$fatal(1,"serializer mismatch after reset");end
 $display("TMDS_SEPARATE_PIXEL_SERIAL_RESET_EXACT_BITS_RESTART_PASS");$finish;
end
initial begin #50000;$fatal(1,"timeout");end
endmodule
