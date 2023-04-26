`timescale 1ns / 1ps

module grey_to_binary #(
    parameter WIDTH = 32
) (
    input [WIDTH-1:0] in_grey,
    output reg [WIDTH-1:0] out_binary
);

    integer i;

    always @(in_grey) begin
        // MSB passes straight through
        out_binary[WIDTH-1] = in_grey[WIDTH-1];

        // MSB-1 down to LSB is formed via XOR of current bit and next (more significant) output bit
        // Note this creates a long XOR chain such that the LSB is dependant on every bit
        for (i = WIDTH-2; i >= 0; i = i - 1) begin
            out_binary[i] = in_grey[i] ^ out_binary[i+1];
        end
    end
endmodule
