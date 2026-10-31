// Simulation-only ideal global clock buffer. Never included in FPGA sources.
`timescale 1ns/1ps
module EG_LOGIC_BUFG(input i, output o);
assign o = i;
endmodule
