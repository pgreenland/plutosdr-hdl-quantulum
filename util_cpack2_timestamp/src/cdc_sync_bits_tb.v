`timescale 1ns / 1ps

module cdc_sync_bits_tb;
    reg clk_out;
    reg reset;
    reg [1:0] bits_in;
    wire [1:0] bits_out;

    cdc_sync_bits #( 
        .NUM_BITS (2)
    ) uut (
        .clk_out(clk_out),
        .reset(reset),
        .bits_in(bits_in),
        .bits_out(bits_out)
    );

    always begin
        // Toggle clock
        #1 clk_out = ~clk_out;
    end

    initial begin
        // Reset signals
        clk_out = 'b0;
        reset = 'b1;
        bits_in = 'h0;

        // De-assert reset
        #3
        reset = 1'b0;

        for (integer i = 0; i < 4; i = i + 1) begin
            // Present input (note passing a counter is not expected usage but works well for testing)
            bits_in = i;

            // Wait a clock cycle for input to be registered
            #2;
        end

        // Wait for final value to pass through syncronizers
        #2;

        $finish;
    end
endmodule
