`timescale 1ns / 1ps

module util_upack2_timestamp #(
  parameter NUM_OF_CHANNELS = 4,
  parameter SAMPLES_PER_CHANNEL = 1,
  parameter SAMPLE_DATA_WIDTH = 16,
  // Limit of how far a timestamp can be in the future as a multiple of timestamp_every (make it a power of two)
  parameter TIMESTAMP_LIMIT_EVERY_MULTIPLE = 16
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

    // Timestamp to compare against data stream every timestamp_every blocks, in DAC clock domain
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
    // Timestamp check types
    localparam TIMESTAMP_CHECK_START_OF_BLOCK = 0;
    localparam TIMESTAMP_CHECK_CONTINUOUS = 1;

    // FIFO write signals
    wire fifo_wr_rst_busy;
    wire fifo_wr_full;
    wire [(1 + 1 + 64 + (NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL))-1:0] fifo_wr_data;
    wire fifo_wr_en;

    // FIFO read signals
    wire fifo_rd_rst_busy;
    wire fifo_rd_empty;
    wire [(1 + 1 + 64 + (NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL))-1:0] fifo_rd_data;
    wire fifo_rd_en;

    // DMA -> DAC FIFO
    xpm_fifo_async #(
        .FIFO_MEMORY_TYPE("block"),
        .FIFO_READ_LATENCY(0), // No output register stages, required for FWFT
        .FIFO_WRITE_DEPTH(16), // FIFO depth is 16 entries (xpm minimum)
        .READ_DATA_WIDTH((1 + 1 + 64 + (NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL))), // xfer_start + timestamp valid + timestamp + data
        .READ_MODE("fwft"), // First word fall though, such that first data is presented on output before empty is cleared
        .SIM_ASSERT_CHK(1), // Enable simulation messages - report misuse
        .USE_ADV_FEATURES("0000"), // Disable all advanced features
        .WRITE_DATA_WIDTH((1 + 1 + 64 + (NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL))) // xfer_start + timestamp valid + timestamp + data
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

    // Timestamp and valid flag
    reg [63:0] last_timestamp = 'h0;
    reg timestamp_valid = 'b0;

    // Combine write data
    assign fifo_wr_data = {transfer_start_dma, timestamp_valid, last_timestamp, s_axis_data};

    // Split read data
    wire transfer_start_dac;
    wire timestamp_valid_dac;
    wire [63:0] timestamp_dac;
    assign transfer_start_dac = fifo_rd_data[NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL + 64 + 1];
    assign timestamp_valid_dac = fifo_rd_data[NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL + 64 + 0];
    assign timestamp_dac = fifo_rd_data[NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL +: 64];
    assign m_axis_data = fifo_rd_data[0 +: NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL];

    // Cross clock domain with timestamp
    wire [63:0] timestamp_dac_grey;
    wire [63:0] timestamp_dma_grey;
    wire [63:0] timestamp_dma_temp;
    reg [63:0] timestamp_dma = 'h0;

    // Convert binary timestamp in DAC domain into grey code
    binary_to_grey #(
        .WIDTH(64)
    )
    timestamp_binary_to_grey (
        .in_binary(timestamp),
        .out_grey(timestamp_dac_grey)
    );

    // Synchronize grey code counter from DAC to DMA clock domains
    cdc_sync_bits #(
        .NUM_BITS(64)
    ) sync_grey_timestamp_dac_to_dma (
        .clk_out(dma_clk),
        .reset('b0),
        .bits_in(timestamp_dac_grey),
        .bits_out(timestamp_dma_grey)
    );

    // Convert grey code timestamp in DMA clock domain into binary
    grey_to_binary #(
        .WIDTH(64)
    )
    timestamp_grey_to_binary (
        .in_grey(timestamp_dma_grey),
        .out_binary(timestamp_dma_temp)
    );

    // Register timetamp in DMA clock domain (hoping the large XOR chain in the grey code to binary conversion meets timing)
    always @(posedge dma_clk) begin
        timestamp_dma <= timestamp_dma_temp;
    end

    // Timestamp block counter, incremented on each input
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

    // Convienience extract 64-bit timestamp from input data
    wire [63:0] s_axis_data_timestamp;
    assign s_axis_data_timestamp = s_axis_data[63:0];

    // Calculate if timestamp is too far in the future or late, if not it's good
    wire timestamp_late_or_too_early;
    assign timestamp_late_or_too_early =    (s_axis_data_timestamp < timestamp_dma) // Late
                                         || (s_axis_data_timestamp > (timestamp_dma + (timestamp_every * TIMESTAMP_LIMIT_EVERY_MULTIPLE))); // Too early

    // Timestamp check discard register
    reg timestamp_check_discard = 'b0;

    // Manage timestamp check
    always @(posedge dma_clk) begin
        if (!s_axis_xfer_req) begin
            // Reset discard reg
            timestamp_check_discard <= 'b0;

        end else begin
            if (s_axis_valid && s_axis_ready && timestamp_req) begin
                // Data is valid and read is being requested, timestamp expected, set discard status
                timestamp_check_discard <= timestamp_late_or_too_early;
            end
        end
    end

    // Assign ready output
    // Host should continunue sending if the following condition is met:
    //  Data is valid and:
    //      Timestamping is disabled and a FIFO write is possible
    //      Timestamping is enabled and this block is to be discarded
    //      Timestamping is enabled, a timestamp check isn't required and a FIFO write is possible
    //      Timestamping is enabled, a timestamp check is required and the timestamp is late or way too early (too far in the future)
    //      Timestamping is enabled, a timestamp check is required, a FIFO write is possible and the timestamp is within allowed range (on time or early, but not too early)
    assign s_axis_ready = s_axis_valid && (    (!timestamp_en && fifo_wr_possible)
                                            || (timestamp_en && timestamp_check_discard)
                                            || (timestamp_en && !timestamp_req && fifo_wr_possible)
                                            || (timestamp_en && timestamp_req && timestamp_late_or_too_early)
                                            || (timestamp_en && timestamp_req && fifo_wr_possible && !timestamp_late_or_too_early)
                                          );

    // Manage last timestamp and last timestamp valid flag
    // This value and its flag get carried across in the fifo to the DAC clock domain, allowing it to hold the first sample in a block
    // before the transmission timestamp is reached
    always @(posedge dma_clk) begin
        if (!s_axis_xfer_req) begin
            // Reset timestamp and valid flag
            last_timestamp <= 'h0;
            timestamp_valid <= 'b0;

        end else begin
            if (s_axis_valid && s_axis_ready && timestamp_en && timestamp_req) begin
                // Data is valid and read is being requested. Timestamp enabled and check required (therefore timestamp present).
                // Capture timestamp and set valid flag
                last_timestamp <= s_axis_data_timestamp;
                timestamp_valid <= 'b1;
            end else begin
                // Data invalid, not ready for more data or no timestamp required yet, reset register and clear flag
                last_timestamp <= 'h0;
                timestamp_valid <= 'b0;
            end
        end
    end

    // Assign fifo write enable
    // Write if:
    //  Space available
    //  and data is valid
    //  and
    //      timestamping disabled
    //      or timestamping enabled, no timestamp is being presented and data isn't being discarded due to timestamp
    assign fifo_wr_en =    fifo_wr_possible
                        && s_axis_valid && s_axis_ready
                        && (    !timestamp_en
                             || (timestamp_en && !timestamp_req && !timestamp_check_discard
                           ));

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

    // Calculate valid - supressing it if the downstream module is being reset or timestamp not yet reached
    assign m_axis_valid = fifo_rd_possible && !transfer_start_rising_stretched_dac && (!timestamp_valid_dac || (timestamp_dac <= timestamp));

    // Assign reset signal, passing ADC module reset through along with reset due to transfer start
    assign reset_upack = reset || transfer_start_rising_stretched_dac;

endmodule
