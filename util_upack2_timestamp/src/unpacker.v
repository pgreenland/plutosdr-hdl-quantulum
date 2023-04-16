`timescale 1ns / 1ps

module unpacker #(
  // Number of channels
  parameter NUM_OF_CHANNELS = 4,
  // Channel width
  parameter CHANNEL_WIDTH = 16

) (
    // Module clock
    input clk,
    
    // Active high reset signal, synchronous to clock
    input reset,

    // Enabled channel count (0->NUM_OF_CHANNELS)
    input [$clog2(NUM_OF_CHANNELS+1)-1:0] enabled_chan_count,

    // Enabled - module should read input and generate outputs
    // Before this is set data should be presented on input
    input en,

    // Ready for next input
    output data_in_ready,

    // Data input
    input [(NUM_OF_CHANNELS*CHANNEL_WIDTH)-1:0] data_in,

    // Output data, ordered such that enabled channels are in lower number inputs.
    // i.e. for two channels enabled, inputs data_in_0 and data_in_1 should be used
    // New data is expected on every clock cycle
    output [CHANNEL_WIDTH-1:0] data_out_0,
    output [CHANNEL_WIDTH-1:0] data_out_1,
    output [CHANNEL_WIDTH-1:0] data_out_2,
    output [CHANNEL_WIDTH-1:0] data_out_3,

    // Output data valid
    output data_out_valid
);
    // Define state machine states - module reset / no channels enabled
    localparam STATE_IDLE = 0;

    // Outputting four words
    localparam STATE_QUAD_A = 1;
    localparam STATE_QUAD_B = 2;

    // Outputting three words
    localparam STATE_TRIPLE_A = 3;
    localparam STATE_TRIPLE_B = 4;
    localparam STATE_TRIPLE_C = 5;
    localparam STATE_TRIPLE_D = 6;
    localparam STATE_TRIPLE_E = 7;

    // Outputting two words
    localparam STATE_DOUBLE_A = 8;
    localparam STATE_DOUBLE_B = 9;

    // Outputting single words
    localparam STATE_SINGLE_A = 10;
    localparam STATE_SINGLE_B = 11;
    localparam STATE_SINGLE_C = 12;
    localparam STATE_SINGLE_D = 13;

    // State machine limit
    localparam STATE_MAX = 14;

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
                    STATE_QUAD_A: state <= STATE_QUAD_B;
                    STATE_QUAD_B: state <= STATE_QUAD_B;
    
                    // Advance through triple output states
                    STATE_TRIPLE_A: state <= STATE_TRIPLE_B;
                    STATE_TRIPLE_B: state <= STATE_TRIPLE_C;
                    STATE_TRIPLE_C: state <= STATE_TRIPLE_D;
                    STATE_TRIPLE_D: state <= STATE_TRIPLE_E;
                    STATE_TRIPLE_E: state <= STATE_TRIPLE_B;
    
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
    reg [(NUM_OF_CHANNELS*CHANNEL_WIDTH)-1:0] last_data_in = 'b0;

    // Manage last data value
    always @(posedge clk) begin
        if (en) begin
            // Update values if enabled
            last_data_in <= data_in;
        end
    end

    // Data request register
    reg data_in_ready_reg;

    // Data output registers
    reg [CHANNEL_WIDTH-1:0] data_out_3_reg;
    reg [CHANNEL_WIDTH-1:0] data_out_2_reg;
    reg [CHANNEL_WIDTH-1:0] data_out_1_reg;
    reg [CHANNEL_WIDTH-1:0] data_out_0_reg;
    reg data_out_valid_reg;

    // Manage output buffer
    always @(posedge clk) begin
        // Assume not ready for next data
        data_in_ready_reg <= 'b0;

        // Assume data outputs reset
        data_out_3_reg <= 'h0;
        data_out_2_reg <= 'h0;
        data_out_1_reg <= 'h0;
        data_out_0_reg <= 'h0;

        // Reset data valid
        data_out_valid_reg <= 'b0;

        // Act if enabled
        if (en) begin
            // Act on state
            case (state)
                // Quad data output
                STATE_QUAD_A: begin
                    // Request data, ensuring the pipeline won't stall
                    data_in_ready_reg <= 'b1;
                end
                STATE_QUAD_B: begin
                    // Output data and request data on each cycle
                    data_out_3_reg <= data_in[(3 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_2_reg <= data_in[(2 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_1_reg <= data_in[(1 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_0_reg <= data_in[(0 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_valid_reg <= 'b1;
                    data_in_ready_reg <= 'b1;
                end
    
                // Triple data output
                STATE_TRIPLE_A: begin
                    // Request data, ensuring we always have a pair of values to work on
                    data_in_ready_reg <= 'b1;
                end
                STATE_TRIPLE_B: begin
                    // Output samples and request data
                    data_out_2_reg <= last_data_in[(2 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_1_reg <= last_data_in[(1 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_0_reg <= last_data_in[(0 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_valid_reg <= 'b1;
                    data_in_ready_reg <= 'b1;
                end
                STATE_TRIPLE_C: begin
                    // Output samples and request data
                    data_out_2_reg <= data_in[(1 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_1_reg <= data_in[(0 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_0_reg <= last_data_in[(3 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_valid_reg <= 'b1;
                    data_in_ready_reg <= 'b1;
                end
                STATE_TRIPLE_D: begin
                    // Output samples
                    data_out_2_reg <= data_in[(0 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_1_reg <= last_data_in[(3 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_0_reg <= last_data_in[(2 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_valid_reg <= 'b1;
                end
                STATE_TRIPLE_E: begin
                    // Output samples and request data
                    data_out_2_reg <= last_data_in[(3 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_1_reg <= last_data_in[(2 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_0_reg <= last_data_in[(1 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_valid_reg <= 'b1;
                    data_in_ready_reg <= 'b1;
                end
    
                // Double output
                STATE_DOUBLE_A: begin
                    // Output samples and request data, one cycle before its needed
                    data_out_1_reg <= data_in[(1 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_0_reg <= data_in[(0 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_valid_reg <= 'b1;
                    data_in_ready_reg <= 'b1;
                end
                STATE_DOUBLE_B: begin
                    // Output samples
                    data_out_1_reg <= data_in[(3 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_0_reg <= data_in[(2 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_valid_reg <= 'b1;
                end
    
                // Single output
                STATE_SINGLE_A: begin
                    // Output sample
                    data_out_0_reg <= data_in[(0 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_valid_reg <= 'b1;
                end
                STATE_SINGLE_B: begin
                    // Output  sample
                    data_out_0_reg <= data_in[(1 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_valid_reg <= 'b1;            
                end
                STATE_SINGLE_C: begin
                    // Output sample and request data, one cycle before its needed
                    data_out_0_reg <= data_in[(2 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_valid_reg <= 'b1;
                    data_in_ready_reg <= 'b1;
                end
                STATE_SINGLE_D: begin
                    // Output sample
                    data_out_0_reg <= data_in[(3 * CHANNEL_WIDTH)+:CHANNEL_WIDTH];
                    data_out_valid_reg <= 'b1;
                end
            endcase
        end
    end
    
    // Assign outputs
    assign data_in_ready = data_in_ready_reg;
    assign data_out_3 = data_out_3_reg;
    assign data_out_2 = data_out_2_reg;
    assign data_out_1 = data_out_1_reg;
    assign data_out_0 = data_out_0_reg;
    assign data_out_valid = data_out_valid_reg;
endmodule
