`timescale 1ns / 1ps

module util_cpack2_timestamp_tb;
    reg clk;
    reg reset;
    reg [63:0] timestamp;
    reg [31:0] timestamp_every;
    reg enable_0;
    reg enable_1;
    reg enable_2;
    reg enable_3;
    reg fifo_wr_en;
    wire fifo_wr_overflow;
    reg [15:0] fifo_wr_data_0;
    reg [15:0] fifo_wr_data_1;
    reg [15:0] fifo_wr_data_2;
    reg [15:0] fifo_wr_data_3;
    wire packed_fifo_wr_en;
    reg packed_fifo_wr_overflow;
    wire packed_fifo_wr_sync;
    wire [63:0] packed_fifo_wr_data;

    util_cpack2_timestamp #( 
        .NUM_OF_CHANNELS (4),
        .SAMPLE_DATA_WIDTH (16),
        .SAMPLES_PER_CHANNEL (1)
    ) uut (
        .clk(clk),
        .adc_clk(clk),
        .reset(reset),
        .timestamp(timestamp),
        .timestamp_every(timestamp_every),
        .enable_0(enable_0),
        .enable_1(enable_1),
        .enable_2(enable_2),
        .enable_3(enable_3),
        .fifo_wr_en(fifo_wr_en),
        .fifo_wr_overflow(fifo_wr_overflow),
        .fifo_wr_data_0(fifo_wr_data_0),
        .fifo_wr_data_1(fifo_wr_data_1),
        .fifo_wr_data_2(fifo_wr_data_2),
        .fifo_wr_data_3(fifo_wr_data_3),
        .packed_fifo_wr_en(packed_fifo_wr_en),
        .packed_fifo_wr_overflow(packed_fifo_wr_overflow),
        .packed_fifo_wr_sync(packed_fifo_wr_sync),
        .packed_fifo_wr_data(packed_fifo_wr_data)
    );

    always begin
        // Toggle clock
        #1 clk = ~clk;
    end

    always @(posedge clk) begin
        // Increment timestamp on every clock cycle
        timestamp = timestamp + 1;
    end

    // Enable values
    reg [3:0] enables [0:14];

    initial begin
        // Prepare enables
        enables[0] = 'b0001;
        enables[1] = 'b0010;
        enables[2] = 'b0100;
        enables[3] = 'b1000;
        enables[4] = 'b0011;
        enables[5] = 'b0110;
        enables[6] = 'b1100;
        enables[7] = 'b0101;
        enables[8] = 'b1010;
        enables[9] = 'b1001;
        enables[10] = 'b1110;
        enables[11] = 'b1101;
        enables[12] = 'b1011;
        enables[13] = 'b0111;
        enables[14] = 'b1111;
    end      

    initial begin
        // Reset signals
        clk = 'b0;
        reset = 'b1;
        enable_0 = 'b0;
        enable_1 = 'b0;
        enable_2 = 'b0;
        enable_3 = 'b0;
        fifo_wr_en = 'b0;
        fifo_wr_data_0 = 'h0;
        fifo_wr_data_1 = 'h0;
        fifo_wr_data_2 = 'h0;
        fifo_wr_data_3 = 'h0;
        packed_fifo_wr_overflow = 'b0;
        timestamp = 0;
        timestamp_every = 4;

        // De-assert reset
        #3
        reset = 1'b0;

        // Wait for internal fifo to come out of reset
        #170;

        for (integer i = 0; i < 15; i = i + 1) begin
            // Assert enables
            {enable_0, enable_1, enable_2, enable_3} = enables[i];
            #2

            // Wait while module resets data path while applying new enables
            #4;

            for (integer j = 0; j < 32; j = j + 4) begin
                // Provide record
                fifo_wr_data_0 = j+1;
                fifo_wr_data_1 = j+2;
                fifo_wr_data_2 = j+3;
                fifo_wr_data_3 = j+4;
                fifo_wr_en = 'b1;
                #2
                fifo_wr_en = 'b0;
                #14
                fifo_wr_data_0 = 'h0000;
                fifo_wr_data_1 = 'h0000;
                fifo_wr_data_2 = 'h0000;
                fifo_wr_data_3 = 'h0000;
            end
        end
        
        $finish;
    end
   
    // Wait for the rising edge of enable signal and print data / sync
    always @(posedge clk) begin
        if (packed_fifo_wr_en == 'b1) begin
            $display("Output: %h, Sync: %b", packed_fifo_wr_data, packed_fifo_wr_sync);
        end
    end
endmodule
