// Hold both existing keys for one second to cycle presentation presets.
// Holding does not repeat; release both before the next selection.
module feature_keys #(parameter integer HOLD_CYCLES=100_000_000)(
    input clk,rst,key1,key2,output reg [2:0] mode
);
reg [1:0] key_meta,key_sync;
reg [26:0] count;
reg fired;
always @(posedge clk or posedge rst) begin
    if(rst) begin key_meta<=3;key_sync<=3;count<=0;fired<=0;mode<=0;end
    else begin
        key_meta<={key2,key1};key_sync<=key_meta;
        if(key_sync==0) begin
            if(!fired) begin
                if(count>=HOLD_CYCLES-1) begin
                    mode<=(mode==4)?0:mode+1'b1;
                    fired<=1;
                end else count<=count+1'b1;
            end
        end else begin count<=0;if(key_sync==3) fired<=0;end
    end
end
endmodule
