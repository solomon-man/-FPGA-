module reset_release(input clk, input async_rst, output rst);
// Preserve the asynchronous assertion / three-clock release synchronizer.
(* syn_preserve = 1, syn_keep = 1, ASYNC_REG = "TRUE" *) reg [2:0] pipe;
always @(posedge clk or posedge async_rst)
    if (async_rst) pipe <= 3'b111;
    else pipe <= {pipe[1:0],1'b0};
assign rst = pipe[2];
endmodule
