`timescale 1ns / 1ps

module bits_to_indexes #(
  // Note if the below is changed, more outputs will need to be added
  parameter BITS_WIDTH = 4
) (
    input [BITS_WIDTH-1:0] bits,
    output reg [$clog2(BITS_WIDTH)-1:0] index_0,
    output reg [$clog2(BITS_WIDTH)-1:0] index_1,
    output reg [$clog2(BITS_WIDTH)-1:0] index_2,
    output reg [$clog2(BITS_WIDTH)-1:0] index_3
);
    // Bit indexes used below
    integer i, j;

    always @(*) begin
        // Reset outputs
        index_0 = 0;
        index_1 = 0;
        index_2 = 0;
        index_3 = 0;

        // Reset next available index
        j = 0;

        // Iterate over inputs
        for (i = 0; i < BITS_WIDTH; i = i + 1) begin
            // Is input bit set?
            if (bits[i] == 1) begin
                // Set output
                if (j == 0) index_0 = i;
                if (j == 1) index_1 = i;
                if (j == 2) index_2 = i;
                if (j == 3) index_3 = i;

                // Increment index
                j = j + 1;
            end
        end
    end
endmodule
