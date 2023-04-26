`timescale 1ns / 1ps

module binary_to_grey #(
    parameter WIDTH = 32
) (
    input [WIDTH-1:0] in_binary,
    output reg [WIDTH-1:0] out_grey
);

    integer i;

    always @(in_binary) begin
        // MSB passes straight through
        out_grey[WIDTH-1] = in_binary[WIDTH-1];

        // MSB-1 down to LSB is formed via XOR of current bit and next (more significant) input bit
        for (i = WIDTH-2; i >= 0; i = i - 1) begin
            out_grey[i] = in_binary[i] ^ in_binary[i+1];
        end
    end
endmodule
