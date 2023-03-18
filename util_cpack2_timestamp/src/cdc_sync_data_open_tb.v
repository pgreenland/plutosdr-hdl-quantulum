`timescale 1ns / 1ps

module cdc_sync_data_open_tb;
    reg clk_in;
    reg clk_out;
    reg enable;
    reg [1:0] bits_in;
    wire valid;
    wire [1:0] bits_out;

    cdc_sync_data_open #( 
        .NUM_BITS (2)
    ) uut (
        .clk_in(clk_in),
        .clk_out(clk_out),
        .enable(enable),
        .bits_in(bits_in),
        .valid(valid),
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
        enable = 'b0;
        bits_in = 'h0;

        // Wait for first input clock edge
        # 3;

        for (integer i = 0; i < 4; i = i + 1) begin
            // Present input
            bits_in = i;

            // Pulse enable for input clock cycle
            enable = 'b1;
            #6;
            enable = 'b0;

            // Wait for input clock to load data
            #18;
        end

        $finish;
    end
endmodule
