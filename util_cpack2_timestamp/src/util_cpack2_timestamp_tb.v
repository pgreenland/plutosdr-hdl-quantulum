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
    wire [127:0] packed_fifo_wr_data;

    util_cpack2_timestamp #( 
        .NUM_OF_CHANNELS (4),
        .SAMPLE_DATA_WIDTH (16),
        .SAMPLES_PER_CHANNEL (1)
    ) uut (
        .clk(clk),
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

    // Test mode
    localparam MODE_READ_VECTORS = 0;
    localparam MODE_WRITE_VECTORS = 1;
    reg mode = MODE_READ_VECTORS;

    // Test vector - sync bit + data bits
    reg [128:0] expected_outputs [0:397];

    initial begin
        // Load test vectors
        if (mode == MODE_READ_VECTORS)
            $readmemb("util_cpack2_timestamp_tv_vectors.mem", expected_outputs);

        // Reset signals
        clk = 'b0;
        reset = 'b1;
        timestamp = 0;
        timestamp_every = 0;
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

        // De-assert reset
        #3
        reset = 1'b0;

        // Perform test sequence a number of times, with increasing timestamp every values
        for (integer i = 0; i < 6; i = i + 1) begin
            // Assert timestamp every
            timestamp_every = i;

            // Iterate through enables
            for (integer j = 0; j < 15; j = j + 1) begin
                // Assert enables
                {enable_0, enable_1, enable_2, enable_3} = enables[j];
    
                // Delay a couple of cycles to allow enables to be counted and packer to change state
                #6; 
    
                for (integer k = 0; k < 48; k = k + 4) begin
                    // Provide record
                    fifo_wr_data_0 = k+1;
                    fifo_wr_data_1 = k+2;
                    fifo_wr_data_2 = k+3;
                    fifo_wr_data_3 = k+4;
                    fifo_wr_en = 'b1;
                    #2
                    fifo_wr_en = 'b0;
                    fifo_wr_data_0 = 'h0000;
                    fifo_wr_data_1 = 'h0000;
                    fifo_wr_data_2 = 'h0000;
                    fifo_wr_data_3 = 'h0000;
                end
            end

            // Delay to allow final output
            #4;
        end

        // Write captured expected vectors out to file
        if (mode == MODE_WRITE_VECTORS)
            $writememb("util_cpack2_timestamp_tv_vectors.mem", expected_outputs);

        // Got this far without error, all must be good
        $display("Test PASSED");

        $finish;
    end
   
    // Wait for the rising edge of enable signal and print data / sync
    integer expected_index = 0;
    always @(posedge clk) begin
        if (packed_fifo_wr_en == 'b1) begin
            // Print values
            $display("Sync: %b", packed_fifo_wr_sync);
            $display("Output: %h", packed_fifo_wr_data[0 +: 64]);
            $display("Output: %h", packed_fifo_wr_data[64 +: 64]);
            
            // Compare to expected (or update expected)
            if (mode == MODE_READ_VECTORS) begin
                // Compare output to expected
                if (expected_outputs[expected_index] != {packed_fifo_wr_sync, packed_fifo_wr_data}) begin
                    $error("Test FAILED, Expected: %h,%b got %h,%b",
                           expected_outputs[expected_index][127:0],
                           expected_outputs[expected_index][128],
                           packed_fifo_wr_data,
                           packed_fifo_wr_sync);
                    $finish;
                end
            end else begin
                // Store output as expected         
                expected_outputs[expected_index] = {packed_fifo_wr_sync, packed_fifo_wr_data};
            end          

            // Increment index
            expected_index = expected_index + 1;
        end
    end
endmodule
