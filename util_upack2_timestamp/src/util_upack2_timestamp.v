`timescale 1ns / 1ps

module util_upack2_timestamp #(
  parameter NUM_OF_CHANNELS = 4,
  parameter SAMPLES_PER_CHANNEL = 1,
  parameter SAMPLE_DATA_WIDTH = 16
) (
    // Module clock
    input clk,

    // Reset - syncrononous to clock
    input reset,

    // Timestamp to compare against data stream every timestamp_every blocks
    input [63:0] timestamp,

    /*
    ** How many 64-bit blocks to expect between timestamp insertions
    ** Depending on the number of enabled channels a block may represent a different number of samples.
    ** For example:
    **  With 4 channels enabled, a block consists of one sample for each channel.
    **  With 3 channels enabled, a block consists of one sample for each channel, with one to thre leftover samples.
    **      It takes 3 blocks, yielding 4 samples per channel to get the least significant channel back in the least significant bit of the block
    **      Timestamping here should ideally be set to a multiple of 3.
    **  With 2 channels enabled, a block consists of two samples for each channel.
    **  With 1 channel enabled, a block consists of four samples for each channel.
    */
    input [31:0] timestamp_every,

    // Channel enables
    input enable_0,
    input enable_1,
    input enable_2,
    input enable_3,

    // Module enable - when set data should be read from stream and written to output
    input fifo_rd_en,

    // Stream input
    input s_axis_valid, // When high s_axis_data contains valid data
    output s_axis_ready, // When high module would like next data block to be loaded into s_axis_data
    input s_axis_xfer_req, // DMA transfer is in progress
    input [2*NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] s_axis_data,

    // Channel output
    output fifo_rd_valid,
    output fifo_rd_underflow,
    output [SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] fifo_rd_data_0,
    output [SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] fifo_rd_data_1,
    output [SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] fifo_rd_data_2,
    output [SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] fifo_rd_data_3
);
    // Check params
    if (NUM_OF_CHANNELS != 4) $error("Currently only 4 channels are supported");

    // Pack enables into a single signal
    wire [NUM_OF_CHANNELS-1:0] enable_s;
    assign enable_s = {enable_3, enable_2, enable_1, enable_0};

    // Enable count signal
    wire [$clog2(NUM_OF_CHANNELS+1)-1:0] enable_count_s;

    // Register for current enabled signal count
    reg [$clog2(NUM_OF_CHANNELS+1)-1:0] enable_count = 'h0;

    // Count enable bits which are set
    count_bits #(
        .BITS_WIDTH (NUM_OF_CHANNELS)
    ) count_bits_impl (
        .bits(enable_s),
        .count(enable_count_s)
    );

    // Enable index signals
    wire [$clog2(NUM_OF_CHANNELS)-1:0] enable_indexes_s [0:NUM_OF_CHANNELS-1];

    // Array of registers for enabled indexes
    reg [$clog2(NUM_OF_CHANNELS)-1:0] enable_indexes [0:NUM_OF_CHANNELS-1];

    // Convert enable signal into index array
    bits_to_indexes bits_to_indexes_impl (
        .bits(enable_s),
        .index_0(enable_indexes_s[0]),
        .index_1(enable_indexes_s[1]),
        .index_2(enable_indexes_s[2]),
        .index_3(enable_indexes_s[3])
    );

    // Number of enabled channels changed
    reg enables_changed = 'b0;

    // Update enable count and index registers, track changes in enable count
    always @(posedge clk) begin : enable_count_index_change
        integer i;

        if (reset == 'b1) begin
            // Reset enable count
            enable_count <= 0;

            // Reset enable indexes
            for (i = 0; i < NUM_OF_CHANNELS; i = i + 1)
                enable_indexes[i] <= 'h0;

            // Clear changed flag
            enables_changed <= 'b0;
        end else begin
            // Update enable count
            enable_count <= enable_count_s;

            // Update indexes
            for (i = 0; i < NUM_OF_CHANNELS; i = i + 1)
                enable_indexes[i] <= enable_indexes_s[i];

            // Update changed flag
            enables_changed <= (enable_count_s != enable_count);
        end
    end














    // TODO DELETE ME
    wire cp_data_out_valid;
    assign cp_data_out_valid = 'b1;

    // Timestamp block counter, incremented on each input block
    // Reset when reaches or exceeds timestamp_every input
    reg [31:0] timestamp_counter = 'h0;

    // Define signal for timestamp enabled / output required
    wire timestamp_en;
    assign timestamp_en = (timestamp_every != 0);
    wire timestamp_req;
    assign timestamp_req = (timestamp_counter == 0);

    // Manage timestamp counter
    always @(posedge clk) begin
        if (reset || !timestamp_en || s_axis_xfer_req == 'b0) begin
            // Reset sample counter
            timestamp_counter <= 0;

        end else if (cp_data_out_valid) begin
            // Sample arrived, increment counter
            if (timestamp_counter >= (timestamp_every - 1)) begin
                // Reset count
                timestamp_counter <= 0;
    
            end else begin
                // Count sample
                timestamp_counter <= timestamp_counter + 1;
            end
        end
    end





    // Channel unpacker inputs
    reg cp_enable = 'b0;
    wire cp_data_in_ready;
    reg [(NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH)-1:0] cp_data_in;

    // Channel unpacker reset (need to reset unpacker on external reset, change in number of channels enabled or end of DMA transfer)
    wire cp_reset;
    assign cp_reset = (reset || enables_changed || !s_axis_xfer_req);

    // Channel unpacker outputs
    wire [SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] cp_data_out [0:3];

    // Channel unpacker
    unpacker #( 
        .NUM_OF_CHANNELS (NUM_OF_CHANNELS),
        .CHANNEL_WIDTH (SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL)
    ) unpacker (
        .clk(clk),
        .reset(cp_reset),
        .enabled_chan_count(enable_count),
        .en(cp_enable),
        .data_in_ready(cp_data_in_ready),
        .data_in(cp_data_in),
        .data_out_0(cp_data_out[0]),
        .data_out_1(cp_data_out[1]),
        .data_out_2(cp_data_out[2]),
        .data_out_3(cp_data_out[3]),
        .data_out_valid(fifo_rd_valid)
    );








    // Read request
    reg s_axis_ready_reg;

    // Register index
    reg reg_zero;

    // Input register state machine
    always @(posedge clk) begin
        if (reset || !s_axis_xfer_req) begin
            // Reset ready flag, preventing more than first word from being presented on input
            s_axis_ready_reg <= 'b0;

            // Reset to read from register zero next
            reg_zero <= 'b1;

            // Reset unpacker enabled flag
            cp_enable <= 'b0;

            // Clear valid and underflow flags
            // TODO

        end else begin
            // Assume ready will be reset
            s_axis_ready_reg <= 'b0;

            // Assume unpacker will be disabled
            cp_enable <= 'b0;

            if (fifo_rd_en && s_axis_valid) begin
                // Module enabled and data valid
                if (timestamp_en) begin
                    // Timestamping enabled
                    if (timestamp_req) begin
                        // Timestamp check required

                    end else begin
                        // No timestamp check required
                    
                    end
                end else begin
                    // Timestamping disabled, ensure module enabled
                    cp_enable <= 'b1;
                    
                    // Provide data if required
                    if (!cp_enable || cp_data_in_ready) begin
                        // CP currently disabled so needs first data, or enabled and requesting data
                        if (reg_zero) begin
                            // Lower word
                            cp_data_in <= s_axis_data[0*(NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH)+:NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH];
                        end else begin
                            // Upper word
                            cp_data_in <= s_axis_data[1*(NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH)+:NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH];
                            
                            // Request next read
                            s_axis_ready_reg <= 'b1;
                        end

                        // Select next register
                        reg_zero <= !reg_zero;
                    end
                end
                
            end else begin
                // Module disabled or no data
            end
        end     
    end

    // Assign output
    assign s_axis_ready = s_axis_ready_reg;










    // Outputs
    reg [SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] data_out_0;
    reg [SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] data_out_1;
    reg [SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] data_out_2;
    reg [SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] data_out_3;

    // Mux unpacker outputs to module outputs based on enable indexes
    always @(*) begin : output_mux 
        integer i;
        integer j;

        // Assume all outputs will be zero
        data_out_0 = 'h0;
        data_out_1 = 'h0;
        data_out_2 = 'h0;
        data_out_3 = 'h0;

        for (i = 0; i < NUM_OF_CHANNELS; i = i + 1)
            if (i < enable_count)
                case (enable_indexes[i])
                    0: data_out_0 = cp_data_out[i];
                    1: data_out_1 = cp_data_out[i];
                    2: data_out_2 = cp_data_out[i];
                    3: data_out_3 = cp_data_out[i];
                endcase
    end

    // Assign outputs
    assign fifo_rd_data_0 = data_out_0;
    assign fifo_rd_data_1 = data_out_1;
    assign fifo_rd_data_2 = data_out_2;
    assign fifo_rd_data_3 = data_out_3;

    // Underflow output
    assign fifo_rd_underflow = (cp_enable && !fifo_rd_valid);

endmodule
