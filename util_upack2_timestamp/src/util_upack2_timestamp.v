`timescale 1ns / 1ps

module util_upack2_timestamp #(
  parameter NUM_OF_CHANNELS = 4,
  parameter SAMPLES_PER_CHANNEL = 1,
  parameter SAMPLE_DATA_WIDTH = 16
) (
    // DMA clock
    input dma_clk,

    // DAC clock
    input dac_clk,

    // Reset from DAC module - syncrononous to DAC clk
    input reset,

    // Reset to upack module - syncrononous to DAC clk
    // Will be asserted if reset above is, or a new DMA transfer starts
    output reset_upack,

    // Timestamp to compare against data stream every timestamp_every blocks, in DMA clock domain
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

    // Stream input, in DMA clock domain
    input s_axis_valid, // When high s_axis_data contains valid data
    output s_axis_ready, // When high module would like next data block to be loaded into s_axis_data
    input s_axis_xfer_req, // DMA transfer is in progress
    input [NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] s_axis_data,

    // Stream output, in DAC clock domain
    output m_axis_valid, // When high s_axis_data contains valid data
    input m_axis_ready, // When high module would like next data block to be loaded into s_axis_data
    output [NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] m_axis_data
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

    // DMA -> DAC FIFO
    xpm_fifo_async #(
        .FIFO_MEMORY_TYPE("block"),
        .FIFO_READ_LATENCY(0), // No output register stages, required for FWFT
        .FIFO_WRITE_DEPTH(16), // FIFO depth is 16 entries (xpm minimum)
        .READ_DATA_WIDTH(NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL+1), // Channel data + xfer_start
        .READ_MODE("fwft"), // First word fall though, such that first data is presented on output before empty is cleared
        .SIM_ASSERT_CHK(1), // Enable simulation messages - report misuse
        .USE_ADV_FEATURES("0000"), // Disable all advanced features
        .WRITE_DATA_WIDTH(NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL+1) // Channel data + xfer_start
    )
    fifo (
        .wr_clk(dma_clk),
        .rst('b0), // Unused reset input, syncronous to wr_clk
        .wr_rst_busy(fifo_wr_rst_busy), // If high wr_en should not be asserted
        .wr_en(fifo_wr_en),
        .din(fifo_wr_data),
        .full(fifo_wr_full),

        .rd_clk(dac_clk),
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

    // Track rising edges in xfer_req indicating start of a DMA transfer
    reg last_s_axis_xfer_req = 'b0;
    wire transfer_start_dma;
    reg held_transfer_start_dma = 'b0;

    always @(posedge dma_clk) begin
        // Update last value
        last_s_axis_xfer_req <= s_axis_xfer_req;

        // Ensure transfer start makes it into FIFO by holding it until next write
        if (!fifo_wr_en) begin
            held_transfer_start_dma <= transfer_start_dma;
        end else begin
            held_transfer_start_dma <= 'b0;       
        end 
    end

    // A transfer has started on rising edge of xfer_req signal
    assign transfer_start_dma = (s_axis_xfer_req && !last_s_axis_xfer_req) || held_transfer_start_dma;

    // Combine write data
    assign fifo_wr_data = {transfer_start_dma, s_axis_data};

    // Split read data
    wire transfer_start_dac;
    assign transfer_start_dac = fifo_rd_data[NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL];
    assign m_axis_data = fifo_rd_data[NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0];

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
        if (!timestamp_en || !s_axis_xfer_req) begin
            // Timestamping disabled or no transfer in progress, reset timestamp counter
            timestamp_counter <= 0;

        end else if (s_axis_valid && s_axis_ready) begin
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

    // Discard data flag, if set data block will be discarded rather than loaded into FIFO
    reg discard_data_reg = 'b0;

    // Convienience extract 64-bit timestamp from input data
    wire [63:0] s_axis_data_timestamp;
    assign s_axis_data_timestamp = s_axis_data[63:0];

    // Assign ready output
    // Host should continunue sending if the following condition is met:
    //  Data is valid and:
    //      This block is to be discarded
    //      Timestamping is disabled and a FIFO write is possible
    //      Timestamping is enabled, a timestamp check isn't required and a FIFO write is possible
    //      Timestamping is enabled, a timestamp check is required and the timestamp is late
    //      Timestamping is enabled, a timestamp check is required, a FIFO write is possible and the timestamp is on time
    assign s_axis_ready = s_axis_valid && (    discard_data_reg
                                            || (!timestamp_en && fifo_wr_possible)
                                            || (timestamp_en && !timestamp_req && fifo_wr_possible)
                                            || (timestamp_en && timestamp_req && (s_axis_data_timestamp < timestamp))
                                            || (timestamp_en && timestamp_req && fifo_wr_possible && (s_axis_data_timestamp == timestamp))
                                          );
   
    // Manage discard data signal
    always @(posedge dma_clk) begin
        if (!s_axis_xfer_req) begin
            // Reset discard flag
            discard_data_reg <= 'b0;

        end else begin     
            if (s_axis_valid && s_axis_ready && timestamp_req) begin
                // Data is valid and read is being requested. Timestamp check required.
                // Update discard flag, discarding samples if timestamping is enabled and timestamp is late
                discard_data_reg <= timestamp_en && (s_axis_data_timestamp < timestamp);
            end
        end     
    end

    // Calculate fifo write enable - write if space available, data is valid, shouldn't be discarded and timestamping is enabled or not required
    assign fifo_wr_en = fifo_wr_possible && s_axis_valid && s_axis_ready && !discard_data_reg && (!timestamp_en || !timestamp_req);

    // Assert transfer start for single clock cycle if it appears from the FIFO
    reg last_transfer_start_dac = 'b0;

    always @(posedge dac_clk) begin
        // Only update last transfer status if fifo output is valid
        if (fifo_rd_possible) begin
            last_transfer_start_dac <= transfer_start_dac; 
        end
    end

    // Ensure transfer start is only asserted for a single clock cycle
    wire transfer_start_rising_dac;
    assign transfer_start_rising_dac = (transfer_start_dac && !last_transfer_start_dac);

    // Stretch transfer start out for a second clock cycle to ensure upack2 resets cleanly
    reg transfer_start_rising_delayed_dac = 'b0;

    always @(posedge dac_clk) begin
        transfer_start_rising_delayed_dac <= transfer_start_rising_dac; 
    end

    // Combine rising edge and delayed signals to form two cycle wide pulse
    wire transfer_start_rising_stretched_dac;
    assign transfer_start_rising_stretched_dac = transfer_start_rising_dac || transfer_start_rising_delayed_dac;

    // Calculate fifo read enable. Perform read when a read is possible, downstream device is ready and downstream device isn't being reset
    assign fifo_rd_en = fifo_rd_possible && m_axis_ready && !transfer_start_rising_stretched_dac;

    // Calculate valid - supressing it if the downstream module is being reset
    assign m_axis_valid = fifo_rd_possible && !transfer_start_rising_stretched_dac;

    // Assign reset signal, passing ADC module reset through along with reset due to transfer start
    assign reset_upack = reset || transfer_start_rising_stretched_dac;

endmodule
