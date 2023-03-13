`timescale 1ns / 1ps

module util_cpack2_timestamp(
    // Clock, should be faster than ADC sample clock. Providing time between samples for timestamping
    input clk,

    // ADC sample clock
    input adc_clk,

    // Reset - syncrononous to ADC sample clock
    input reset,

    // Timestamp to sample and report every x samples - syncrononous to clk
    input [63:0] timestamp,

    /*
    ** How many samples to output between timestamp insertions
    ** Note this will probably want to be set to match the DMA buffer size, such that a timestamp isn't
    ** inserted in the middle of a batch of samples
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
    input [15:0] fifo_wr_data_0,
    input [15:0] fifo_wr_data_1,
    input [15:0] fifo_wr_data_2,
    input [15:0] fifo_wr_data_3,

    // FIFO output - syncrononous to clk
    output packed_fifo_wr_en,
    input packed_fifo_wr_overflow,
    output packed_fifo_wr_sync,
    output [63:0] packed_fifo_wr_data
);
    // Syncronized reset from ADC domain
    wire reset_synced;

    // Syncronize reset from ADC domain
    cdc_sync_bits sync_reset (
        .clk_out(clk),
        .reset(0),
        .bits_in(reset),
        .bits_out(reset_synced)
    );

    // Syncronized timestamp every signal
    wire [31:0] timestamp_every_synced;

    // Syncronize timestamp every
    cdc_sync_data_freeze #( 
        .NUM_BITS (32)
    ) sync_timestamp_every (
        .clk_in(adc_clk),
        .clk_out(clk),
        .bits_in(timestamp_every),
        .bits_out(timestamp_every_synced)
    );

    // Pack enables into a single signal
    wire [3:0] enable_s;
    assign enable_s = {enable_3, enable_2, enable_1, enable_0};

    // Syncronized enable signal
    wire [3:0] enable_s_synced;

    // Syncronize enables
    cdc_sync_data_freeze #( 
        .NUM_BITS (4)
    ) sync_enable (
        .clk_in(adc_clk),
        .clk_out(clk),
        .bits_in(enable_s),
        .bits_out(enable_s_synced)
    );

    // Enable count signal
    wire [2:0] enable_count_s;

    // Register for current enabled signal count
    reg [2:0] enable_count;

    // Count enable bits which are set
    count_bits #(
        .BITS_WIDTH (4)
    ) count_bits_impl (
        .bits(enable_s_synced),
        .count(enable_count_s)
    );

    // Enable index signals
    wire [1:0] enable_indexes_s [0:3];

    // Array of registers for enabled indexes
    reg [1:0] enable_indexes [0:3];

    // Convert enable signal into index array
    bits_to_indexes bits_to_indexes_impl (
        .bits(enable_s_synced),
        .index_0(enable_indexes_s[0]),
        .index_1(enable_indexes_s[1]),
        .index_2(enable_indexes_s[2]),
        .index_3(enable_indexes_s[3])
    );

    // Track last value of enable, to detect changes
    reg [3:0] last_enable_s;

    // Enable changed strobe, high for one clock cycle after change in enables detected
    reg enables_changed;

    // Monitor for changes in enables, updating count and index registers
    always @(posedge clk) begin : monitor_enable_for_changes
        integer i;

        if (reset_synced == 'b1) begin
            // Reset last enable state
            last_enable_s <= 'h0;

            // Reset enable count
            enable_count <= 0;

            // Reset enable indexes
            for (i = 0; i < 4; i = i + 1) enable_indexes[i] <= 'h0;
        end else begin
            // Strobe enables changed if last and current enable values don't match
            enables_changed <= (enable_s_synced != last_enable_s) ? 'b1 : 'b0; 

            // Cache enable state
            last_enable_s <= enable_s_synced;

            // Update count
            enable_count <= enable_count_s;

            // Update indexes
            for (i = 0; i < 4; i = i + 1) enable_indexes[i] <= enable_indexes_s[i];
        end
    end

    // Pack data inputs into single signal
    wire [63:0] fifo_wr_data_s = {fifo_wr_data_3, fifo_wr_data_2, fifo_wr_data_1, fifo_wr_data_0};

    // Reset busy signals
    wire sync_fifo_wr_reset_busy;
    wire sync_fifo_rd_reset_busy;

    // Write enable signal
    wire sync_fifo_wr_en;
    assign sync_fifo_wr_en = fifo_wr_en & ~(reset || sync_fifo_wr_reset_busy); // Write whenever ADC ready but not in reset

    // Read empty / enable signals
    wire sync_fifo_rd_empty;
    reg sync_fifo_rd_en;

    // Data read from fifo
    wire [63:0] fifo_wr_data_int;

    // Bodge signals with timestamp
    wire [127:0] fifo_wr_data_s_with_timestamp;
    assign fifo_wr_data_s_with_timestamp = {timestamp, fifo_wr_data_s};
    wire [127:0] fifo_wr_data_int_with_timestamp;
    wire [63:0] timestamp_temp;
    assign timestamp_temp = fifo_wr_data_int_with_timestamp[127:64];
    assign fifo_wr_data_int = fifo_wr_data_int_with_timestamp[63:0];

    // Syncronizing fifo
    xpm_fifo_async #(
       //.FIFO_MEMORY_TYPE("distributed"),
       .FIFO_WRITE_DEPTH(16),
       //.READ_DATA_WIDTH(64),
       .READ_DATA_WIDTH(128),
       .SIM_ASSERT_CHK(1),
       //.WRITE_DATA_WIDTH(64)
       .WRITE_DATA_WIDTH(128)
    )
    data_sync (  
       //.data_valid(data_valid),

       //.dout(fifo_wr_data_int),
       .dout(fifo_wr_data_int_with_timestamp),
       .empty(sync_fifo_rd_empty),
       .rd_rst_busy(sync_fifo_rd_reset_busy),
       .wr_rst_busy(sync_fifo_wr_reset_busy),
       //.din(fifo_wr_data_s),
       .din(fifo_wr_data_s_with_timestamp),
       .rd_clk(clk),
       .rd_en(sync_fifo_rd_en),
       .rst(reset),
       .wr_clk(adc_clk),
       .wr_en(sync_fifo_wr_en)
    );

    // Define state machine states
    parameter STATE_RESET = 0;
    parameter STATE_WAIT_FOR_DATA = 1;
    parameter STATE_READ_DATA = 2;
    parameter STATE_TIMESTAMP_HEADER = 3;
    parameter STATE_TIMESTAMP_VALUE = 4;
    parameter STATE_STORE_DATA = 5;
    parameter STATE_OUTPUT_DATA = 6;
    parameter STATE_MAX = 7;

    // State register
    reg [$clog2(STATE_MAX)-1:0] state;

    // Output registers
    reg [63:0] packed_data;

    // Timestamp cache register
    reg [63:0] timestamp_first_sample;

    // Timestamp sample counter, incremented on each input
    // Reset when reaches or exceeds timestamp_every input
    reg [31:0] timestamp_counter;

    // Declare counter registers for input and output position
    reg [1:0] index_in;
    reg [1:0] index_out;

    // Multiplexer, selecting between enable indexes based on index_in
    wire [2:0] input_index;
    assign input_index = enable_indexes[index_in];

    // Multiplexer, selecting input data based on index above
    reg [15:0] input_data;
    always @(*) begin : select_input
        integer i;

        // Reset data
        input_data = 'h0;

        // Select appropriate word from input register
        for (i = 0; i < 4; i = i + 1) begin
            if (input_index == i) input_data = fifo_wr_data_int[(i*16)+:16];
        end 
    end

    // Buffer synchronized (first entry in output buffer is first enabled channel)
    reg buffer_synced;

    // Write and sync strobes
    reg write_sync_strobe;
    reg write_strobe;

    // State machine logic
    always @(posedge clk) begin : manage_state_machine
        integer i;

        if (reset_synced == 'b1 || enables_changed == 'b1) begin
            // Reset was asserted or enables changed, reset state machine
            state <= STATE_RESET;

        end else begin
            // Act on state
            case (state)
                STATE_RESET: begin
                    // De-assert syncronizing FIFO read signal
                    sync_fifo_rd_en <= 'b0;

                    // Reset indexes
                    index_in <= 'h0;
                    index_out <= 'h0;

                    // Reset sample counter
                    timestamp_counter <= 0;

                    // Advance to wait for data
                    state <= STATE_WAIT_FOR_DATA;
                end
                STATE_WAIT_FOR_DATA: begin
                    // Wait for data in fifo
                    if (sync_fifo_rd_empty == 'b0) begin
                        // Assert read signal
                        sync_fifo_rd_en <= 'b1;
                        
                        // Advance to read data
                        state <= STATE_READ_DATA;
                    end
                end
                STATE_READ_DATA: begin
                    // De-assert read signal
                    sync_fifo_rd_en <= 'b0;

                    // Process sample if channels enabled
                    if (enable_count != 0) begin
                        // Capture timestamp if sample is destined for first out index
                        if (index_out == 0) begin
                            timestamp_first_sample <= timestamp_temp;
                        end

                        // If timestamping enabled, manage counter
                        if (timestamp_every_synced != 0) begin
                            if (timestamp_counter >= (timestamp_every_synced - 1)) begin
                                // Reset count
                                timestamp_counter <= 0;
    
                            end else begin
                                // Count sample
                                timestamp_counter <= timestamp_counter + 1;
                            end
                        end

                        // Flag if this record will be syncronized (first value in output is first enabled input or timestamp present)
                        if (index_out == 0 && index_in == 0) begin
                            if (timestamp_every_synced == 0) begin
                                // Timestamping is not enabled, output sync on data alignments
                                buffer_synced <= 'b1;
                            end else if (timestamp_counter == 0) begin
                                // Timestamping is enabled, data is aligned and timestamp is being output, flag sync
                                buffer_synced <= 'b1;
                            end
                        end

                        if (timestamp_counter == 0 && timestamp_every_synced != 0) begin
                            // Advance to output timestamp before processing data
                            state <= STATE_TIMESTAMP_HEADER;

                        end else begin
                            // Advance to store data
                            state <= STATE_STORE_DATA;
                        end
                    end
                end
                STATE_TIMESTAMP_HEADER: begin
                    // Timestamp header should be presented on output, while strobe pulsed.
                    // Reset synced flag, such that it's only output with timestamp header and not data
                    buffer_synced <= 'b0;

                    // Advance to output value.
                    state <= STATE_TIMESTAMP_VALUE; 
                end
                STATE_TIMESTAMP_VALUE: begin
                    // Timestamp value should be presented on output, while strobe pulsed. Advance to store current data.
                    state <= STATE_STORE_DATA;
                end
                STATE_STORE_DATA: begin
                    // Update next output index with data from next input index
                    for (i = 0; i < 4; i = i + 1) begin
                        if (index_out == i) packed_data[(i*16)+:16] <= input_data;
                    end

                    // Check input index
                    if (index_in == (enable_count - 1)) begin
                        // Reset index
                        index_in <= 'h0;

                        // Expect to return to wait state
                        state <= STATE_WAIT_FOR_DATA;
                    end else begin
                        // Increment index
                        index_in <= index_in + 1;
                    end

                    // Check output index
                    if (index_out == 3) begin
                        // Reset index
                        index_out <= 'h0;

                        // Advance to output
                        state <= STATE_OUTPUT_DATA;
                    end else begin
                        // Increment index
                        index_out <= index_out + 1;
                    end
                end
                STATE_OUTPUT_DATA: begin
                    // Reset synced flag
                    buffer_synced <= 'b0;

                    // If items remain to be processed, return to store
                    if (index_in != 0) begin
                        // Continue storing data
                        state <= STATE_STORE_DATA;

                    end else begin
                        // Return to wait for next data
                        state <= STATE_WAIT_FOR_DATA;
                    end
                end
            endcase
        end
    end

    // Select output based on state
    reg [63:0] packed_fifo_select;
    always @(*) begin
        // Strobes should usually be low
        write_strobe <= 'b0;
        write_sync_strobe <= 'b0;

        // Present data normally
        packed_fifo_select = packed_data;

        case (state)
                STATE_TIMESTAMP_HEADER: begin
                    // Write strobe should be high and sync presented
                    write_strobe <= 'b1;
                    write_sync_strobe <= buffer_synced;

                    // Preset magic number
                    packed_fifo_select = 'h504D5453454D4954;
                end
                STATE_TIMESTAMP_VALUE: begin
                    // Write strobe should be high and sync presented
                    write_strobe <= 'b1;
                    write_sync_strobe <= buffer_synced;

                    // Preset stored timestamp
                    packed_fifo_select = timestamp_first_sample;
                end
                STATE_OUTPUT_DATA: begin
                    // Write strobe should be high and sync presented
                    write_strobe <= 'b1;
                    write_sync_strobe <= buffer_synced;
                end
        endcase
    end

    // Assign fifo outputs
    assign packed_fifo_wr_en = write_strobe;
    assign packed_fifo_wr_sync = write_sync_strobe;
    assign packed_fifo_wr_data = packed_fifo_select;

    // Module can't suffer from overflows itself, so pass downstream flag up through syncronizer
    cdc_sync_bits sync_overflow (
        .clk_out(adc_clk),
        .reset(0),
        .bits_in(packed_fifo_wr_overflow),
        .bits_out(fifo_wr_overflow)
    );
endmodule
