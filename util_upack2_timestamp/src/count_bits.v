`timescale 1ns / 1ps

module count_bits #(
  parameter BITS_WIDTH = 4
) (
    input [BITS_WIDTH-1:0] bits,
    output reg [$clog2(BITS_WIDTH):0] count
);

    // Bit index used below
    integer i;

    always @(*)
    begin
        // Initialize count variable.
        count = 0;
    
        for (i = 0; i < BITS_WIDTH; i = i + 1) begin
            // Add bit to count
            count = count + bits[i];
        end
    end

endmodule
