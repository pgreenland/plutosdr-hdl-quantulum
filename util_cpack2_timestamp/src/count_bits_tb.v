`timescale 1ns / 1ps

module count_bits_tb;
    reg [3:0] bits;
    wire [2:0] count;

    count_bits #(
        .BIT_WIDTH (4)
    ) uut (
        .bits(bits),
        .count(count)
    );

    initial begin
        // Present sequence of values
        for (integer i = 0; i < 16; i = i + 1) begin
            // Present value and delay
            bits = i;
            #10;
        end
        
        // Final delay before stopping simulation    
        #10 $finish;
    end
endmodule
