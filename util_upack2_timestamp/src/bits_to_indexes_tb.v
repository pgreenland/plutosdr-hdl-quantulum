`timescale 1ns / 1ps

module bits_to_indexes_tb;
    reg [3:0] bits;
    wire [1:0] index_0;
    wire [1:0] index_1;
    wire [1:0] index_2;
    wire [1:0] index_3;

    bits_to_indexes uut (
        .bits(bits),
        .index_0(index_0),
        .index_1(index_1),
        .index_2(index_2),
        .index_3(index_3)
    );

    initial begin
        // Present sequence of values
        for (integer i = 0; i < 16; i = i + 1) begin
            // Present value and delay
            bits <= i;
            #10;
        end
        
        // All done  
        $finish;
    end
endmodule
