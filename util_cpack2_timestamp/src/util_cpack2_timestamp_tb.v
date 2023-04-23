`timescale 1ns / 1ps

module util_cpack2_timestamp_tb;
    reg adc_clk;
    reg dma_clk;
    reg [63:0] timestamp;
    reg [31:0] timestamp_every;
    reg packed_fifo_wr_en;
    wire packed_fifo_wr_overflow;
    reg packed_fifo_wr_sync;
    reg [63:0] packed_fifo_wr_data;
    wire packed_timestamped_fifo_wr_en;
    reg packed_timestamped_fifo_wr_overflow;
    wire packed_timestamped_fifo_wr_sync;
    wire [63:0] packed_timestamped_fifo_wr_data;

    util_cpack2_timestamp #( 
        .NUM_OF_CHANNELS (4),
        .SAMPLE_DATA_WIDTH (16),
        .SAMPLES_PER_CHANNEL (1)
    ) uut (
        .adc_clk(adc_clk),
        .dma_clk(dma_clk),
        .timestamp(timestamp),
        .timestamp_every(timestamp_every),
        .packed_fifo_wr_en(packed_fifo_wr_en),
        .packed_fifo_wr_overflow(packed_fifo_wr_overflow),
        .packed_fifo_wr_sync(packed_fifo_wr_sync),
        .packed_fifo_wr_data(packed_fifo_wr_data),
        .packed_timestamped_fifo_wr_en(packed_timestamped_fifo_wr_en),
        .packed_timestamped_fifo_wr_overflow(packed_timestamped_fifo_wr_overflow),
        .packed_timestamped_fifo_wr_sync(packed_timestamped_fifo_wr_sync),
        .packed_timestamped_fifo_wr_data(packed_timestamped_fifo_wr_data)
    );

    always begin
        // Delay to align rising edges of clocks
        #1;
        
        // Toggle ADC clock at 1/4 rate of DAC clock (providing some space clock cycles in insert timestamps)
        while (1)
            #4 adc_clk = ~adc_clk;
    end

    always begin
        // Toggle DMA clock
        #1 dma_clk = ~dma_clk;
    end

    always @(posedge dma_clk) begin
        // Increment timestamp on every clock cycle
        timestamp = timestamp + 1;
    end   

    // Test mode
    localparam MODE_READ_VECTORS = 0;
    localparam MODE_WRITE_VECTORS = 1;
    reg mode = MODE_READ_VECTORS;

    // Test vector - sync bit + data bits
    reg [64:0] expected_outputs [0:26];

    integer i, j;

    initial begin
        // Load test vectors
        if (mode == MODE_READ_VECTORS)
            $readmemb("util_cpack2_timestamp_tv_vectors.mem", expected_outputs);

        // Reset signals
        adc_clk = 'b0;
        dma_clk = 'b0;
        timestamp = 0;
        timestamp_every = 0;
        packed_fifo_wr_en = 'b0;
        packed_fifo_wr_sync = 'b0;
        packed_fifo_wr_data = 'h0;
        packed_timestamped_fifo_wr_overflow = 'b0;

        // Wait for rising edge of ADC clock
        @(posedge adc_clk);

        // Wait for FIFO to come out of reset
        #260;

        // Reset sample counter
        j = 0;

        // Perform test with timestamping disabled and enabled
        for (i = 0; i < 2; i = i + 1) begin
            // Set mode
            @(posedge dma_clk)
            if (i == 0) begin
                // Timestamping disabled
                timestamp_every = 'h0;
            end else begin
                // Timestamping enabled
                timestamp_every = 'h4;
            end

            // Iterate through test values
            while (j < ((i + 1) * 48)) begin
                // Provide record
                @(posedge adc_clk)
                packed_fifo_wr_data[48+:16] <= j + 4;
                packed_fifo_wr_data[32+:16] <= j + 3;
                packed_fifo_wr_data[16+:16] <= j + 2;
                packed_fifo_wr_data[0+:16] <= j + 1;
                packed_fifo_wr_sync <= (j % 8 == 0) ? 'b1 : 'b0; // Assert sync every other value
                packed_fifo_wr_en <= 'b1;

                // Increment index
                j = j + 4;
            end

            // Reset inputs
            @(posedge adc_clk)
            packed_fifo_wr_en <= 'b0;
            packed_fifo_wr_sync <= 'b0;
            packed_fifo_wr_data <= 'h0;

            // Delay to allow final output
            #28;
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
    always @(posedge dma_clk) begin
        if (packed_timestamped_fifo_wr_en == 'b1) begin
            // Print values
            $display("Output: %b,%h", packed_timestamped_fifo_wr_sync, packed_timestamped_fifo_wr_data);
            
            // Compare to expected (or update expected)
            if (mode == MODE_READ_VECTORS) begin
                // Compare output to expected
                if (expected_outputs[expected_index] != {packed_timestamped_fifo_wr_sync, packed_timestamped_fifo_wr_data}) begin
                    $error("Test FAILED, Expected: %h,%b got %h,%b",
                           expected_outputs[expected_index][63:0],
                           expected_outputs[expected_index][64],
                           packed_timestamped_fifo_wr_data,
                           packed_timestamped_fifo_wr_sync);
                    $finish;
                end
            end else begin
                // Store output as expected         
                expected_outputs[expected_index] = {packed_timestamped_fifo_wr_sync, packed_timestamped_fifo_wr_data};
            end          

            // Increment index
            expected_index = expected_index + 1;
        end
    end
endmodule
