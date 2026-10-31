// Simulation stand-in for the TD primitive used by the reference levels module.
module AL_MAP_LUT1 #(parameter [1:0] INIT=2'b10,parameter EQN="A")(output o,input a);
assign o=INIT[a];
endmodule
