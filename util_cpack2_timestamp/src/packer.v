`timescale 1ns / 1ps

module packer #(
  // Number of channels
  parameter NUM_OF_CHANNELS = 4,
  // Channel width
  parameter CHANNEL_WIDTH = 16

) (
    // Module clock
    input clk,
    
    // Active high reset signal, synchronous to clock
    input reset,

    // Input timestamp
    input [63:0] timestamp_in,

    // Enabled channel count (0->NUM_OF_CHANNELS)
    input [$clog2(NUM_OF_CHANNELS+1)-1:0] enabled_chan_count,

    // Input enabled
    input en,

    // Input data, ordered such that enabled channels are in lower number inputs.
    // i.e. for two channels enabled, inputs data_in_0 and data_in_1 should be used
    // New data is expected on every clock cycle
    input [CHANNEL_WIDTH-1:0] data_in_0,
    input [CHANNEL_WIDTH-1:0] data_in_1,
    input [CHANNEL_WIDTH-1:0] data_in_2,
    input [CHANNEL_WIDTH-1:0] data_in_3,

    // Data output sync strobe (channel 0 is in LSB of output)
    output data_out_sync,

    // Data output valid strobe
    output data_out_valid,

    // Data outputs
    output [(NUM_OF_CHANNELS*CHANNEL_WIDTH)-1:0] data_out,
    output [(NUM_OF_CHANNELS*CHANNEL_WIDTH)-1:0] timestamp_out
);
    // Define state machine states - module reset / no channels enabled
    localparam STATE_IDLE = 0;

    // Outputting four words
    localparam STATE_QUAD_A = 1;

    // Outputting three words
    localparam STATE_TRIPLE_A = 2;
    localparam STATE_TRIPLE_B = 3;
    localparam STATE_TRIPLE_C = 4;
    localparam STATE_TRIPLE_D = 5;

    // Outputting two words
    localparam STATE_DOUBLE_A = 6;
    localparam STATE_DOUBLE_B = 7;

    // Outputting single words
    localparam STATE_SINGLE_A = 8;
    localparam STATE_SINGLE_B = 9;
    localparam STATE_SINGLE_C = 10;
    localparam STATE_SINGLE_D = 11;

    // State machine limit
    localparam STATE_MAX = 12;

    // State register
    reg [$clog2(STATE_MAX)-1:0] state = STATE_IDLE;

    // First state in cycle
    reg [$clog2(STATE_MAX)-1:0] first_state_for_enable;

    // Decide on first state in cycle based on enable signals
    always @(*) begin
        case (enabled_chan_count)
            1: first_state_for_enable = STATE_SINGLE_A;
            2: first_state_for_enable = STATE_DOUBLE_A;
            3: first_state_for_enable = STATE_TRIPLE_A;
            4: first_state_for_enable = STATE_QUAD_A;
            default: first_state_for_enable = STATE_IDLE;
        endcase
    end

    // Manage state machine
    always @(posedge clk) begin
        if (reset) begin
            // Return to first state based on enables
            state <= first_state_for_enable;

        end else begin
            if (en) begin
                // Act on state
                case (state)   
                    // Expect output on each cycle, consider changing state
                    STATE_QUAD_A: state <= STATE_QUAD_A;
    
                    // Advance through triple output states
                    STATE_TRIPLE_A: state <= STATE_TRIPLE_B;
                    STATE_TRIPLE_B: state <= STATE_TRIPLE_C;
                    STATE_TRIPLE_C: state <= STATE_TRIPLE_D;
                    STATE_TRIPLE_D: state <= STATE_TRIPLE_A;
    
                    // Advance through dual output states
                    STATE_DOUBLE_A: state <= STATE_DOUBLE_B;
                    STATE_DOUBLE_B: state <= STATE_DOUBLE_A;
    
                    // Advance through single output states
                    STATE_SINGLE_A: state <= STATE_SINGLE_B;
                    STATE_SINGLE_B: state <= STATE_SINGLE_C;
                    STATE_SINGLE_C: state <= STATE_SINGLE_D;
                    STATE_SINGLE_D: state <= STATE_SINGLE_A;
    
                    // Unknown state, return to first state based on enables
                    default: state <= first_state_for_enable;
                endcase
            end     
        end
    end

    // Last data value
    reg [CHANNEL_WIDTH-1:0] last_data_in_0 = 'b0;
    reg [CHANNEL_WIDTH-1:0] last_data_in_1 = 'b0;
    reg [CHANNEL_WIDTH-1:0] last_data_in_2 = 'b0;
    reg [CHANNEL_WIDTH-1:0] last_data_in_3 = 'b0;

    // Manage last data value
    always @(posedge clk) begin
        if (en) begin
            // Update values if enabled
            last_data_in_0 <= data_in_0;
            last_data_in_1 <= data_in_1;
            last_data_in_2 <= data_in_2;
            last_data_in_3 <= data_in_3;
        end
    end

    // Output value, strobe and sync
    reg sync = 'b0;
    reg valid = 'b0;
    reg [NUM_OF_CHANNELS*CHANNEL_WIDTH-1:0] data = 'b0;
    reg [NUM_OF_CHANNELS*CHANNEL_WIDTH-1:0] timestamp = 'b0;    

    // Manage output buffer
    always @(posedge clk) begin
        // Expect strobe and sync to be reset
        sync <= 'b0;
        valid <= 'b0;

        // Act if enabled
        if (en) begin
            // Act on state
            case (state)
                // Quad data output
                STATE_QUAD_A: begin
                    // Output data and toggle strobe on each cycle
                    sync <= 'b1; // First channel is in LSB
                    valid <= 'b1;
                    timestamp <= timestamp_in;
                    data <= {data_in_3, data_in_2, data_in_1, data_in_0};
                end
    
                // Triple data output
                STATE_TRIPLE_A: begin
                    // Capture timestamp on first cycle
                    timestamp <= timestamp_in;
                end
                STATE_TRIPLE_B: begin
                    // Output three from last and one from current
                    sync <= 'b1; // First channel is in LSB
                    valid <= 'b1;
                    data <= {data_in_0, last_data_in_2, last_data_in_1, last_data_in_0};
                end
                STATE_TRIPLE_C: begin
                    // Output two from last and two from current
                    valid <= 'b1;
                    data <= {data_in_1, data_in_0, last_data_in_2, last_data_in_1};
           
                end
                STATE_TRIPLE_D: begin
                    // Output one from last and three from current
                    valid <= 'b1;
                    data <= {data_in_2, data_in_1, data_in_0, last_data_in_2};
                end
    
                // Double output
                STATE_DOUBLE_A: begin
                    // Capture timestamp on first cycle
                    timestamp <= timestamp_in;
                end
                STATE_DOUBLE_B: begin
                    // Output two from last and two from current
                    sync <= 'b1; // First channel is in LSB
                    valid <= 'b1;
                    data <= {data_in_1, data_in_0, last_data_in_1, last_data_in_0};
                end
    
                // Single output
                STATE_SINGLE_A: begin
                    // Capture timestamp on first cycle
                    timestamp <= timestamp_in;
    
                    // Update individual words
                    data[0*CHANNEL_WIDTH +: CHANNEL_WIDTH] <= data_in_0;
                end
                STATE_SINGLE_B: begin
                    // Update individual words
                    data[1*CHANNEL_WIDTH +: CHANNEL_WIDTH] <= data_in_0;            
                end
                STATE_SINGLE_C: begin
                    // Update individual words
                    data[2*CHANNEL_WIDTH +: CHANNEL_WIDTH] <= data_in_0;
                end
                STATE_SINGLE_D: begin
                    // Update individual words and strobe output
                    sync <= 'b1; // First channel is in LSB
                    valid <= 'b1;
                    data[3*CHANNEL_WIDTH +: CHANNEL_WIDTH] <= data_in_0;
                end
            endcase
        end
    end

    // Assign outputs
    assign data_out_sync = sync;
    assign data_out_valid = valid;
    assign data_out = data;
    assign timestamp_out = timestamp;

endmodule
