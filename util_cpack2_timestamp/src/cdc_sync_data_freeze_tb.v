`timescale 1ns / 1ps

module cdc_sync_data_freeze_tb;
    reg clk_in;
    reg clk_out;
    reg [1:0] bits_in;
    wire [1:0] bits_out;

    cdc_sync_data_freeze #( 
        .NUM_BITS (2)
    ) uut (
        .clk_in(clk_in),
        .clk_out(clk_out),
        .bits_in(bits_in),
        .bits_out(bits_out)
    );

    always begin
        // Toggle input clock (slower than output and out of phase)
        #3 clk_in = ~clk_in;
    end

    always begin
        // Toggle output clock
        #1 clk_out = ~clk_out;
    end

    initial begin
        // Reset signals
        clk_in = 'b0;
        clk_out = 'b0;
        bits_in = 'h0;

        // Wait for first input clock edge
        # 3;

        for (integer i = 0; i < 4; i = i + 1) begin
            // Present input
            bits_in = i;

            // Wait for input clock to load data and ack to be returned
            #24;
        end

        $finish;
    end
endmodule
