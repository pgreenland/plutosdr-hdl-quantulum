`timescale 1ns / 1ps

/*
** From: https://www.verilogpro.com/clock-domain-crossing-part-2/
**
** This module can be used for syncronizing bits between clock domains.
** Multiple related bits may be passed together.
** The module uses a open loop technique, such that an enable signal is passed from
** the source to destination clock domains via a synchronizer. The delay added by this
** ensures the values on the data bus between the domains has settled before being loaded
** into the desination domain.
** This means however that the source domain must be clocked slower than the desination domain
** with three clock cycles in the destination domain required for every one in the source domain.
*/

module cdc_sync_data_open #(
  // Number of dependent input / output bits
  parameter NUM_BITS = 1

) (
    // Input domain clock
    input clk_in,

    // Output domain clock
    input clk_out,

    // Input enable
    input enable,

    // Input data
    input [NUM_BITS-1:0] bits_in,

    // Output valid (output register has been updated)
    output valid,

    // Output data
    output [NUM_BITS-1:0] bits_out
);
    // Input register - holding data frozen in input domain
    (* ASYNC_REG = "TRUE" *) reg [NUM_BITS-1:0] input_reg = 'h0;
    
    // Output register - holding data captured from input domain
    (* QUANTULUM_LTD_FALSE_PATH = 1 *) (* ASYNC_REG = "TRUE" *) reg [NUM_BITS-1:0] output_reg = 'h0;

    // Output valid register
    reg output_valid_reg = 'b0;

    // Input to output load state (input clock domain)
    reg load_in = 'b0;
    
    // Input to output load state (output clock domain)
    wire load_out;

    // Last value of load_out signal
    reg last_load_out = 'b0;

    // Syncronize load signal between domains
    cdc_sync_bits sync_load_in_to_out (
        .clk_out(clk_out),
        .reset(0),
        .bits_in(load_in),
        .bits_out(load_out)
    );

    // Input domain clock
    always @(posedge clk_in)
    begin
        if (enable) begin
            // Input enabled, load next data
            input_reg <= bits_in;
            
            // Toggle request to signal to output clock domain
            load_in <= ~load_in;
        end
    end

    // Output domain clock
    always @(posedge clk_out)
    begin
        if (load_out != last_load_out) begin
            // Request arrived from input clock domain, transfer data
            output_reg <= input_reg;

            // Flag output valid
            output_valid_reg <= 'b1;

        end else begin
            // Flag output invalid
            output_valid_reg <= 'b0;
        end  

        // Update last load out
        last_load_out <= load_out;
    end

    // Drive outputs from registers
    assign bits_out = output_reg;
    assign valid = output_valid_reg;
endmodule

