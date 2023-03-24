`timescale 1ns / 1ps

module packer_tb;
    reg clk;
    reg reset;
    reg [63:0] timestamp_in;
    reg [2:0] enabled_chan_count;
    reg en;
    reg [15:0] data_in_0;
    reg [15:0] data_in_1;
    reg [15:0] data_in_2;
    reg [15:0] data_in_3;
    wire data_out_sync;
    wire data_out_valid;
    wire [63:0] data_out;
    wire [63:0] timestamp_out;

    packer uut (
        .clk(clk),
        .reset(reset),
        .timestamp_in(timestamp_in),
        .enabled_chan_count(enabled_chan_count),
        .en(en),
        .data_in_0(data_in_0),
        .data_in_1(data_in_1),
        .data_in_2(data_in_2),
        .data_in_3(data_in_3),
        .data_out_sync(data_out_sync),
        .data_out_valid(data_out_valid),
        .data_out(data_out),
        .timestamp_out(timestamp_out)
    );

    always begin
        // Toggle clock
        #1 clk = ~clk;
    end

    always @(posedge clk) begin
        // Increment timestamp on every clock cycle
        timestamp_in = timestamp_in + 1;
    end

    // Enable values
    reg [2:0] enabled_chans [0:3];

    initial begin
        // Prepare enables
        enabled_chans[0] = 1;
        enabled_chans[1] = 2;
        enabled_chans[2] = 3;
        enabled_chans[3] = 4;
    end

    initial begin
        // Reset signals
        clk = 'b0;
        reset = 'b0;
        timestamp_in = 'h0;
        enabled_chan_count = 'b0;
        en = 'b1;
        data_in_0 = 'b0;
        data_in_1 = 'b0;
        data_in_2 = 'b0;
        data_in_3 = 'b0;

        // Delay to align with rising edge of clock (is this right?)
        #1;

        for (integer i = 0; i < 4; i = i + 1) begin
            // De-assert enable
            en = 'b0;

            // Update channel enable
            enabled_chan_count = enabled_chans[i];
            #2;
            reset = 'b1;
            #2; // Delay for entry into first state from reset
            reset = 'b0;

            // Assert enable
            en = 'b1;

            for (integer j = 0; j < 32; j = j + 4) begin
                // Provide record
                data_in_0 = j+1;
                data_in_1 = j+2;
                data_in_2 = j+3;
                data_in_3 = j+4;
                #2;
            end
        end

        $finish;

    end    

    // Wait for the rising edge of enable signal and print data / sync
    always @(posedge clk) begin
        if (data_out_valid == 'b1) begin
            $display("Output: %h, Timestamp: %h, Sync: %b", data_out, timestamp_out, data_out_sync);
        end
    end

endmodule
