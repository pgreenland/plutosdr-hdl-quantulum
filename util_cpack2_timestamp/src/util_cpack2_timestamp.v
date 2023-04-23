`timescale 1ns / 1ps

module util_cpack2_timestamp #(
  parameter NUM_OF_CHANNELS = 4,
  parameter SAMPLES_PER_CHANNEL = 1,
  parameter SAMPLE_DATA_WIDTH = 16
) (
    // ADC clock
    input adc_clk,

    // DMA clock
    input dma_clk,

    // Timestamp to stamp data stream with every timestamp_every blocks, in DMA clock domain
    input [63:0] timestamp,

    /*
    ** How many NUM_OF_CHANNELS * SAMPLES_PER_CHANNEL * SAMPLE_DATA_WIDTH blocks to expect between timestamp insertions, in DMA clock domain
    ** Depending on the number of enabled channels a block may represent a different number of samples.
    ** For example when NUM_OF_CHANNELS = 4 and SAMPLES_PER_CHANNEL = 1:
    **  With 4 channels enabled, a block consists of one sample for each channel.
    **  With 3 channels enabled, a block consists of one sample for each channel, with one to thre leftover samples.
    **      It takes 3 blocks, yielding 4 samples per channel to get the least significant channel back in the least significant bit of the block
    **      Timestamping here should ideally be set to a multiple of 3.
    **  With 2 channels enabled, a block consists of two samples for each channel.
    **  With 1 channel enabled, a block consists of four samples for each channel.
    */
    input [31:0] timestamp_every,

    // FIFO input
    input packed_fifo_wr_en,
    output packed_fifo_wr_overflow,
    input packed_fifo_wr_sync,
    input [NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] packed_fifo_wr_data,

    // FIFO output
    output packed_timestamped_fifo_wr_en,
    input packed_timestamped_fifo_wr_overflow,
    output packed_timestamped_fifo_wr_sync,
    output [NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] packed_timestamped_fifo_wr_data
);
    // FIFO write signals
    wire fifo_wr_rst_busy;
    wire fifo_wr_full;
    wire [NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL:0] fifo_wr_data;
    wire fifo_wr_en;

    // FIFO read signals
    wire fifo_rd_rst_busy;
    wire fifo_rd_empty;
    wire [NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL:0] fifo_rd_data;
    wire fifo_rd_en;

    // ADC -> DMA FIFO
    xpm_fifo_async #(
        .FIFO_MEMORY_TYPE("block"),
        .FIFO_READ_LATENCY(0), // No output register stages, required for FWFT
        .FIFO_WRITE_DEPTH(16), // FIFO depth is 16 entries (xpm minimum)
        .READ_DATA_WIDTH(NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL+1), // Channel data + sync
        .READ_MODE("fwft"), // First word fall though, such that first data is presented on output before empty is cleared
        .SIM_ASSERT_CHK(1), // Enable simulation messages - report misuse
        .USE_ADV_FEATURES("0000"), // Disable all advanced features
        .WRITE_DATA_WIDTH(NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL+1) // Channel data + sync
    )
    fifo (
        .wr_clk(adc_clk),
        .rst('b0), // Unused reset input, syncronous to wr_clk
        .wr_rst_busy(fifo_wr_rst_busy), // If high wr_en should not be asserted
        .wr_en(fifo_wr_en),
        .din(fifo_wr_data),
        .full(fifo_wr_full),

        .rd_clk(dma_clk),
        .rd_rst_busy(fifo_rd_rst_busy), // If high rd_en should not be asserted
        .empty(fifo_rd_empty),
        .rd_en(fifo_rd_en),
        .dout(fifo_rd_data),
        
        .sleep('b0)
    );

    // Calculate when a fifo write is possible, aka fifo isn't busy and isn't full
    wire fifo_wr_possible;
    assign fifo_wr_possible = !fifo_wr_rst_busy && !fifo_wr_full;

    // Calculate when a fifo read is possible
    wire fifo_rd_possible;
    assign fifo_rd_possible = !fifo_rd_rst_busy && !fifo_rd_empty;

    // Combine write data
    assign fifo_wr_data = {packed_fifo_wr_sync, packed_fifo_wr_data};

    // Calculate fifo write enable - write if space available and data is valid
    assign fifo_wr_en = fifo_wr_possible && packed_fifo_wr_en;

    // Split read data
    wire fifo_data_sync_dma;
    wire [NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] fifo_data_dma;
    assign fifo_data_sync_dma = fifo_rd_data[NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL];
    assign fifo_data_dma = fifo_rd_data[NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0];

    // Timestamp block counter, incremented on each output from packer
    // Reset when reaches or exceeds timestamp_every input
    reg [31:0] timestamp_counter = 'h0;

    // Define signal for timestamp enabled / output required
    wire timestamp_en;
    assign timestamp_en = (timestamp_every != 0);
    wire timestamp_req;
    assign timestamp_req = (timestamp_counter == 0);  

    // Manage timestamp counter
    always @(posedge dma_clk) begin
        if (!timestamp_en) begin
            // Timestamping disabled, reset timestamp counter
            timestamp_counter <= 0;

        end else if (fifo_rd_possible) begin
            // Timestamp counter enabled and data should be read, count sample
            if (timestamp_counter >= timestamp_every) begin
                // Reset counter
                timestamp_counter <= 0;
    
            end else begin
                // Increment counter
                timestamp_counter <= timestamp_counter + 1;
            end
        end
    end

    // Calculate fifo read signal, read when possible and timestamp not enabled or not being output
    assign fifo_rd_en = fifo_rd_possible && (!timestamp_en || !timestamp_req);

    // FIFO output registers
    reg packed_timestamped_fifo_wr_en_reg = 'b0;
    reg packed_timestamped_fifo_wr_sync_reg = 'b0;
    reg [NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] packed_timestamped_fifo_wr_data_reg = 'h0;

    // Manage FIFO read
    always @(posedge dma_clk) begin
        // Assume output write en, sync and data reset
        packed_timestamped_fifo_wr_en_reg <= 'b0;
        packed_timestamped_fifo_wr_sync_reg <= 'b0;
        packed_timestamped_fifo_wr_data_reg <= 'h0;

        if (fifo_rd_possible) begin
            // FIFO read possible, in fwft mode so data is waiting on output
            if (timestamp_en && timestamp_req) begin
                // Timestamping enabled and required, output timestamp
                packed_timestamped_fifo_wr_data_reg <= timestamp;
                packed_timestamped_fifo_wr_sync_reg <= fifo_data_sync_dma; // Report sync on timestamp + input in sync
                packed_timestamped_fifo_wr_en_reg <= 'b1;

            end else begin
                // Timestamping disabled or not required, output data
                packed_timestamped_fifo_wr_data_reg <= fifo_data_dma;
                packed_timestamped_fifo_wr_sync_reg <= timestamp_en ? 'b0 : fifo_data_sync_dma; // Output sync signal if timestamp disabled
                packed_timestamped_fifo_wr_en_reg <= 'b1;
            end
        end
    end

    // Assign FIFO outputs
    assign packed_timestamped_fifo_wr_en = packed_timestamped_fifo_wr_en_reg;
    assign packed_timestamped_fifo_wr_sync = packed_timestamped_fifo_wr_sync_reg;
    assign packed_timestamped_fifo_wr_data = packed_timestamped_fifo_wr_data_reg;

    // Module can't suffer from overflows itself, so pass downstream flag up, crossing clock domains
    wire overflow_sync_ready;
    reg delayed_packed_timestamped_fifo_wr_overflow_reg = 'b0;
    wire curr_or_delayed_packed_timestamped_fifo_wr_overflow;
    assign curr_or_delayed_packed_timestamped_fifo_wr_overflow = packed_timestamped_fifo_wr_overflow || delayed_packed_timestamped_fifo_wr_overflow_reg;

    cdc_sync_data_closed #( 
        .NUM_BITS (1)
    ) overflow_sync (
        .clk_in(dma_clk),
        .clk_out(adc_clk),
        .ready(overflow_sync_ready),
        .enable('b1),
        .bits_in(curr_or_delayed_packed_timestamped_fifo_wr_overflow),
        .bits_out(packed_fifo_wr_overflow)
    );

    // Ensure overflows occuring while the syncronizer is busy are reported
    always @(posedge dma_clk) begin
        if (overflow_sync_ready) begin
            // Reset delayed value
            delayed_packed_timestamped_fifo_wr_overflow_reg <= 'b0;

        end else begin
            // Check for overflow while sycnronizer busy
            if (packed_timestamped_fifo_wr_overflow) begin
                // Hold delayed value such that it will be reported when the syncronizer is ready again
                delayed_packed_timestamped_fifo_wr_overflow_reg <= 'b1;
            end           
        end
    end
endmodule
