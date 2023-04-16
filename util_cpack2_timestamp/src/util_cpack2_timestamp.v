`timescale 1ns / 1ps

module util_cpack2_timestamp #(
  parameter NUM_OF_CHANNELS = 4,
  parameter SAMPLES_PER_CHANNEL = 1,
  parameter SAMPLE_DATA_WIDTH = 16
) (
    // Module clock
    input clk,

    // Reset - syncrononous to clock
    input reset,

    // Timestamp to sample and report every timestamp_every blocks
    input [63:0] timestamp,

    /*
    ** How many 64-bit blocks to output between timestamp insertions
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

    // Channel input
    input fifo_wr_en,
    output fifo_wr_overflow,
    input [SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] fifo_wr_data_0,
    input [SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] fifo_wr_data_1,
    input [SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] fifo_wr_data_2,
    input [SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] fifo_wr_data_3,

    // FIFO output
    output packed_fifo_wr_en,
    input packed_fifo_wr_overflow,
    output packed_fifo_wr_sync,
    output [2*NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] packed_fifo_wr_data
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

    // Channel packer inputs
    reg [SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] cp_data_in [0:3];

    // Mux module inputs to packer inputs based on enable indexes
    always @(*) begin : input_mux 
        integer i;

        for (i = 0; i < NUM_OF_CHANNELS; i = i + 1)
            case (enable_indexes[i])
                0: cp_data_in[i] = fifo_wr_data_0;
                1: cp_data_in[i] = fifo_wr_data_1;
                2: cp_data_in[i] = fifo_wr_data_2;
                3: cp_data_in[i] = fifo_wr_data_3;
                default: cp_data_in[i] = 'h0;
            endcase
    end

    // Channel packer outputs
    wire cp_data_out_sync;
    wire cp_data_out_valid;
    wire [NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] cp_data_out;
    wire [NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] cp_timestamp_out;

    // Channel packer reset (need to reset packer on external reset, or change in number of channels enabled)
    wire cp_reset;
    assign cp_reset = (reset || enables_changed);

    // Channel packer
    packer #( 
        .NUM_OF_CHANNELS (NUM_OF_CHANNELS),
        .CHANNEL_WIDTH (SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL)
    ) packer (
        .clk(clk),
        .reset(cp_reset),
        .timestamp_in(timestamp),
        .enabled_chan_count(enable_count),
        .en(fifo_wr_en),
        .data_in_0(cp_data_in[0]),
        .data_in_1(cp_data_in[1]),
        .data_in_2(cp_data_in[2]),
        .data_in_3(cp_data_in[3]),
        .data_out_sync(cp_data_out_sync),
        .data_out_valid(cp_data_out_valid),
        .data_out(cp_data_out),
        .timestamp_out(cp_timestamp_out)
    );

    // Timestamp block counter, incremented on each output from packer
    // Reset when reaches or exceeds timestamp_every input
    reg [31:0] timestamp_counter = 'h0;

    // Define signal for timestamp enabled / output required
    wire timestamp_en;
    assign timestamp_en = (timestamp_every != 0);
    wire timestamp_req;
    assign timestamp_req = (timestamp_counter == 0);

    // Manage timestamp counter
    always @(posedge clk) begin
        if (reset || !timestamp_en) begin
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

    // Write and sync strobes
    reg write_sync_strobe = 'b0;
    reg write_strobe = 'b0;
    reg [NUM_OF_CHANNELS*SAMPLE_DATA_WIDTH*SAMPLES_PER_CHANNEL-1:0] write_data [0:2];
    initial begin
        write_data[0] = 'h0;
        write_data[1] = 'h0;
        write_data[2] = 'h0;
    end

    // Define state machine states
    localparam STATE_INDEX_0 = 0;
    localparam STATE_INDEX_1 = 1;
    localparam STATE_OVERFLOW = 2;
    localparam STATE_MAX = 3;

    // State register
    reg [$clog2(STATE_MAX)-1:0] state = STATE_INDEX_0;

    // Output register state machine
    always @(posedge clk) begin
        if (reset) begin
            // Reset state
            state <= STATE_INDEX_0;

            // Clear write and sync strobes
            write_strobe <= 'b0;
            write_sync_strobe <= 'b0; 

        end else begin
            // Assume write will be reset
            write_strobe <= 'b0;
    
            // Check for write signal from packer
            if (cp_data_out_valid == 'b1) begin           
                // Packer has data, act on state
                case (state)
                    STATE_INDEX_0: begin
                        // Empty buffer, expect data word to be stored and state changed
                        write_data[0] <= cp_data_out;
                        state <= STATE_INDEX_1;
        
                        // Is timestamping enabled and timestamp required?
                        if (timestamp_en && timestamp_req) begin
                            // Yes, output both timestamp and data
                            write_data[0] <= cp_timestamp_out;
                            write_data[1] <= cp_data_out;
                            write_strobe <= 'b1;
        
                            // Stay in this state as we're outputting two words
                            state <= STATE_INDEX_0;
                        end
        
                        // Is timestamping enabled?
                        if (timestamp_en == 'b1) begin
                            // Yes, sync strobe follows timestamp request with channel 0 in LSB
                            write_sync_strobe <= (cp_data_out_sync && timestamp_req);
                            
                        end else begin
                            // No, sync strobe will follow packer sync - i.e. sync will be indicated if channel 0 is in LSB
                            write_sync_strobe <= cp_data_out_sync;
                        end                    
                    end
                    STATE_INDEX_1: begin
                        // One word buffered already, expect another to be added before both output
                        write_data[1] <= cp_data_out;
                        write_strobe <= 'b1;
                        state <= STATE_INDEX_0;
        
                        // Is timestamping enabled and timestamp required?
                        if (timestamp_en && timestamp_req) begin
                            // Yes, oh dear, output stored word and timestamp. Storing current data as overflow
                            write_data[1] <= cp_timestamp_out;
                            write_data[2] <= cp_data_out;
        
                            // Advance to overflow state
                            state <= STATE_OVERFLOW;
                        end                  
                    end
                    STATE_OVERFLOW: begin
                        // What a mess, we have a leftover word from last time and a new word from this transfer, expect to return to empty buffer
                        write_data[0] <= write_data[2];
                        write_data[1] <= cp_data_out;
                        write_strobe <= 'b1;
                        state <= STATE_INDEX_0;
    
                        // Is timestamping enabled and timestamp required?
                        if (timestamp_en && timestamp_req) begin
                            // Yes, oh geez, it happened again (someone must have changed the enables).
                            // Output stored word and timestamp. Storing current data as overflow
                            write_data[1] <= cp_timestamp_out;
                            write_data[2] <= cp_data_out;
        
                            // Hold in overflow state
                            state <= STATE_OVERFLOW;
                        end  
    
                        // Ensure sync strobe cleared (we might be in sync, but the user can probably wait a sample or two here)
                        write_sync_strobe <= 'b0;
                    end
                    default: begin
                        // Return to index 0
                        state <= STATE_INDEX_0;
                    end
                endcase
            end
        end     
    end

    // Assign fifo outputs
    assign packed_fifo_wr_en = write_strobe;
    assign packed_fifo_wr_sync = write_sync_strobe;
    assign packed_fifo_wr_data = {write_data[1], write_data[0]};

    // Module can't suffer from overflows itself, so pass downstream flag up
    assign fifo_wr_overflow = packed_fifo_wr_overflow;
endmodule
