`timescale 1ns / 1ps

/*
** From: https://www.verilogpro.com/clock-domain-crossing-part-1
**
** This module can be used for syncronizing bits between clock domains.
** If used with multiple bits, these should not be dependant on one another as they may not arrive
** in the output clock domain on the same cycle. For example if sending a strobe and enable, which needs
** to occur on the same cycle the use of this syncronizer would not be appropriate.
*/

module cdc_sync_bits #(
  // Number of independent input / output bits
  parameter NUM_BITS = 1

) (
    // Output domain clock
    input clk_out,

    // Output domain clock reset
    input reset,

    // Input data
    input [NUM_BITS-1:0] bits_in,

    // Output data
    output [NUM_BITS-1:0] bits_out
);

    // Two stage ff syncronizer
    (* QUANTULUM_LTD_FALSE_PATH = 1 *) (* ASYNC_REG = "TRUE" *) reg [NUM_BITS-1:0] stage_1 = 'h0;
    (* ASYNC_REG = "TRUE" *) reg [NUM_BITS-1:0] stage_2 = 'h0;

    always @(posedge clk_out)
    begin
        if (reset == 'b1) begin
            // Reset both stages
            stage_1 <= 'h0;
            stage_2 <= 'h0;
        end else begin
            // Advance bit through stages
            stage_1 <= bits_in;
            stage_2 <= stage_1;
        end
    end

    // Assign output to stage two
    assign bits_out = stage_2;
endmodule
