`timescale 1ns / 1ps

/*
** From: https://www.verilogpro.com/clock-domain-crossing-design-part-3/
**
** This module can be used for syncronizing bits between clock domains.
** Multiple related bits may be passed together.
** The module uses a closed loop technique, such that once the data to pass
** has been registered in the source clock domain it's frozen until feedback
** is received from the destination clock domain.
** This means that while data will arrive coherently it will be delayed as
** the source clock domain will wait for feedback from the desintation before
** performing the next transfer
*/

module cdc_sync_data_closed #(
  // Number of dependent input / output bits
  parameter NUM_BITS = 1

) (
    // Input domain clock
    input clk_in,

    // Output domain clock
    input clk_out,

    // Input ready (if enable was asserted data transfer will be performed)
    output ready,

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

    // Write request (input clock domain)
    reg req_in = 'b0;
    
    // Write request (output clock domain)
    wire req_out;

    // Write acknowledge (output clock domain)
    reg ack_out = 'b0;

    // Write acknowledge (input clock domain)
    wire ack_in;

    // Syncronize request and acknowledge between domains
    cdc_sync_bits sync_req_in_to_out (
        .clk_out(clk_out),
        .reset(0),
        .bits_in(req_in),
        .bits_out(req_out)
    );

    cdc_sync_bits sync_ack_out_to_in (
        .clk_out(clk_in),
        .reset(0),
        .bits_in(ack_out),
        .bits_out(ack_in)
    );

    // Ready signal
    assign ready = (req_in == ack_in);

    // Input domain clock
    always @(posedge clk_in)
    begin
        if (enable && req_in == ack_in) begin
            // Input enabled and last request acknowledged, load next data
            input_reg <= bits_in;
            
            // Toggle request to signal to output clock domain
            req_in <= ~req_in;
        end
    end

    // Output domain clock
    always @(posedge clk_out)
    begin
        if (req_out != ack_out) begin
            // Request arrived from input clock domain, transfer data
            output_reg <= input_reg;

            // Flag output valid
            output_valid_reg <= 'b1;

            // Toggle acknowledge to signal input clock domain
            ack_out <= ~ack_out;

        end else begin
            // Flag output invalid
            output_valid_reg <= 'b0;
        end    
    end

    // Drive outputs from registers
    assign bits_out = output_reg;
    assign valid = output_valid_reg;
endmodule

