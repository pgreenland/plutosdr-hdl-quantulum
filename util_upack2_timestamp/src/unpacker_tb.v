`timescale 1ns / 1ps

module unpacker_tb;
    reg clk;
    reg reset;
    reg [2:0] enabled_chan_count;
    reg en;
    wire data_in_ready;
    reg [63:0] data_in;
    wire [15:0] data_out_0;
    wire [15:0] data_out_1;
    wire [15:0] data_out_2;
    wire [15:0] data_out_3;
    wire data_out_valid;

    unpacker uut (
        .clk(clk),
        .reset(reset),
        .enabled_chan_count(enabled_chan_count),
        .en(en),
        .data_in_ready(data_in_ready),
        .data_in(data_in),
        .data_out_0(data_out_0),
        .data_out_1(data_out_1),
        .data_out_2(data_out_2),
        .data_out_3(data_out_3),
        .data_out_valid(data_out_valid)
    );

    always begin
        // Toggle clock
        #1 clk = ~clk;
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

    integer j;

    initial begin
        // Reset signals
        clk = 'b0;
        reset = 'b0;
        enabled_chan_count = 'b0;
        en = 'b0;
        data_in = 'b0;

        // Delay to align with rising edge of clock (is this right?)
        #1;

        for (integer i = 0; i < 4; i = i + 1) begin
            // Update channel enable
            enabled_chan_count <= enabled_chans[i];
            #2;
            reset <= 'b1;
            #2; // Delay for entry into first state from reset
            reset <= 'b0;

            // Provide data
            j = 0;
            while (j < 48) begin
                // Provide data on first clock cycle, or request
                if (j == 0 || data_in_ready == 'b1) begin
                    // Provide record
                    data_in[63:48] <= j+4;
                    data_in[47:32] <= j+3;
                    data_in[31:16] <= j+2;
                    data_in[15:0] <= j+1;

                    // Assert enable (once first data word provided)
                    en <= 'b1;

                    // Increment index   
                    j = j + 4;
                end

                #2; // Delay for clock cycle
            end

            // Delay for final output
            case (i+1)
                1: #6;
                2: #6;
                3: #2;
            endcase

            // De-assert enable
            en <= 'b0;
        end

        // Wait few final cycles
        #4;

        // All done
        $finish;

    end    

    // Wait for the enable signal to be high before printing data
    always @(posedge clk) begin
        if (data_out_valid) begin
            if (enabled_chan_count >= 1) $display("Output0: %h", data_out_0);
            if (enabled_chan_count >= 2) $display("Output1: %h", data_out_1);
            if (enabled_chan_count >= 3) $display("Output2: %h", data_out_2);
            if (enabled_chan_count >= 4) $display("Output3: %h", data_out_3);
        end
    end

endmodule
