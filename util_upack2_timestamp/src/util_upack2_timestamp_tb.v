`timescale 1ns / 1ps

module util_upack2_timestamp_tb;
    reg dma_clk;
    reg dac_clk;
    reg reset;
    wire reset_upack;
    reg [63:0] timestamp;
    reg [31:0] timestamp_every;
    reg s_axis_valid;
    wire s_axis_ready;
    reg s_axis_xfer_req;
    reg [63:0] s_axis_data;
    wire m_axis_valid;
    wire m_axis_ready;
    wire [63:0] m_axis_data;

    util_upack2_timestamp #( 
        .NUM_OF_CHANNELS (4),
        .SAMPLE_DATA_WIDTH (16),
        .SAMPLES_PER_CHANNEL (1),
        .TIMESTAMP_LIMIT_EVERY_MULTIPLE (16)
    ) uut (
        .dma_clk(dma_clk),
        .dac_clk(dac_clk),
        .reset(reset),
        .reset_upack(reset_upack),
        .timestamp(timestamp),
        .timestamp_every(timestamp_every),
        .s_axis_valid(s_axis_valid),
        .s_axis_ready(s_axis_ready),
        .s_axis_xfer_req(s_axis_xfer_req),
        .s_axis_data(s_axis_data),
        .m_axis_valid(m_axis_valid),
        .m_axis_ready(m_axis_ready),
        .m_axis_data(m_axis_data)
    );

    always begin
        // Toggle DMA clock
        #1 dma_clk = ~dma_clk;
    end

    always begin
        // Delay to align rising edges of clocks
        #1;
        
        // Toggle DAC clock at 1/16 rate of DMA clock (providing some space clock cycles in insert timestamps)
        while (1)
            #16 dac_clk = ~dac_clk;
    end

    always @(posedge dac_clk) begin
        // Increment timestamp
        timestamp <= timestamp + 1;
    end 

    // Test mode
    localparam MODE_READ_VECTORS = 0;
    localparam MODE_WRITE_VECTORS = 1;
    reg mode = MODE_READ_VECTORS;

    // Test vector - unpack reset + data bits
    localparam EXPECTED_OUTPUT_COUNT = 57;
    reg [64:0] expected_outputs [0:EXPECTED_OUTPUT_COUNT-1];

    integer i, j;
    reg ts_req;

    initial begin
        // Load test vectors
        if (mode == MODE_READ_VECTORS)
            $readmemb("util_upack2_timestamp_tv_vectors.mem", expected_outputs);

        // Reset signals
        dma_clk = 'b0;
        dac_clk = 'b0;
        reset = 'b1;
        timestamp = 'h0;
        timestamp_every = 'h0;
        s_axis_valid = 'b0;
        s_axis_xfer_req = 'b0;
        s_axis_data = 'h0;

        // De-assert reset
        @(posedge dac_clk)
        reset <= 1'b0;

        // Reset sample counter
        j = 0;

        // Perform test with timestamping disabled, enabled and late, enabled and on time, enabled and early, enabled and very early (making DAC domain wait)
        for (i = 0; i < 6; i = i + 1) begin
            // Set mode
            if (i == 0) begin
                // Timestamping disabled
                timestamp_every = 'h0;
            end else begin
                // Timestamping enabled
                timestamp_every = 'h4;
            end

            // Assert transfer request
            @(posedge dma_clk)
            s_axis_xfer_req <= 'b1;

            // Iterate through test values
            ts_req = 'b1;
            while (j < ((i + 1) * 48)) begin          
                // Provide data on first step, or if ready asserted
                @(posedge dma_clk)
                if (!s_axis_valid || s_axis_ready) begin
                    // Insert timestamp every x blocks
                    if (timestamp_every != 0 && ((j / 4) % timestamp_every == 0) && ts_req) begin
                        // Provide timestamp
                        case (i)
                            // Timestamp late
                            1: s_axis_data[63:0] <= timestamp - 10;
                            // Timestamp on time
                            2: s_axis_data[63:0] <= timestamp + 1;
                            // Timestamp early
                            3: s_axis_data[63:0] <= timestamp + 5;
                            // Timestamp very early
                            4: s_axis_data[63:0] <= timestamp + 10;
                            // Timestamp waaaay too early
                            5: s_axis_data[63:0] <= timestamp + 200;
                        endcase

                        // Assert data valid
                        s_axis_valid <= 'b1;
                        
                        // Clear timestamp required
                        ts_req <= 'b0;
                    end else begin
                        // Provide record
                        s_axis_data[48+:16] <= j+4;
                        s_axis_data[32+:16] <= j+3;
                        s_axis_data[16+:16] <= j+2;
                        s_axis_data[0+:16] <= j+1;
                        s_axis_valid <= 'b1;
                
                        // Increment index
                        j = j + 4;

                        // Set timestamp required
                        ts_req <= 'b1;
                    end
                end
            end
           
            // Wait for final value to be consumed
            @(posedge dma_clk)
            while (!s_axis_ready) begin
                #2;       
            end

            // Clear valid flag, reset data and deassert transfer request
            s_axis_data <= 'h0;
            s_axis_valid <= 'b0;
            s_axis_xfer_req <= 'b0;
            
            // Wait for reads to complete
            #800;
        end

        // Write captured expected vectors out to file
        if (mode == MODE_WRITE_VECTORS)
            $writememb("util_upack2_timestamp_tv_vectors.mem", expected_outputs);

        // Got this far without error, all must be good
        $display("Test PASSED");

        // All done
        $finish;
    end
   
    // Wait for valid signal and print data
    integer expected_index = 0;
    always @(posedge dac_clk) begin
        if (reset_upack) begin
            $display("Output: Reset");
        end

        if (m_axis_valid) begin
            // Dump data
            $display("Output: %h", m_axis_data);
        end

        if (reset_upack || m_axis_valid) begin
            // Compare to expected (or update expected)
            if (mode == MODE_READ_VECTORS) begin
                // Compare output to expected
                if (expected_index >= EXPECTED_OUTPUT_COUNT) begin
                    $error("Test FAILED, Unexpected output data");
                    //$finish;
                end
                else if (expected_outputs[expected_index] != {reset_upack, m_axis_valid ? m_axis_data : 64'h0}) begin
                    $error("Test FAILED, Expected: %b,%h got %b,%h at index %0d",
                           expected_outputs[expected_index][64],
                           expected_outputs[expected_index][63:0],
                           reset_upack,
                           m_axis_valid ? m_axis_data : 64'h0,
                           expected_index);
                    $finish;
                end
            end else begin
                // Store output as expected         
                expected_outputs[expected_index] = {reset_upack, m_axis_valid ? m_axis_data : 64'h0};
            end          

            // Increment index
            expected_index = expected_index + 1;
        end
    end

    // For test purposes we'll accept data whenever we can get it
    assign m_axis_ready = m_axis_valid;
endmodule
