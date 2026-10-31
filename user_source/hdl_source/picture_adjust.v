module picture_adjust #(
    parameter integer BRIGHTNESS = 0, // signed additive offset, -255..255
    parameter integer CONTRAST = 128 // 128 = exact unity
)(input [23:0] rgb_in,output [23:0] rgb_out);
function [7:0] adjust;
    input [7:0] value;
    integer signed result_value;
    begin
        result_value = (($signed({1'b0,value})-128)*CONTRAST >>> 7)+128+BRIGHTNESS;
        if(result_value<0) adjust=0;
        else if(result_value>255) adjust=255;
        else adjust=result_value[7:0];
    end
endfunction
assign rgb_out={adjust(rgb_in[23:16]),adjust(rgb_in[15:8]),adjust(rgb_in[7:0])};
endmodule
