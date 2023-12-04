`timescale 1ns / 1ps

module util_wr_sync_mux_tb;
    reg clk;
    reg [31:0] timestamp_every;
    reg timestamp_wr_sync_in;
    reg ext_wr_sync_in;
    wire sync_out;

    util_wr_sync_mux uut (
        .clk(clk),
        .timestamp_every(timestamp_every),
        .timestamp_wr_sync_in(timestamp_wr_sync_in),
        .ext_wr_sync_in(ext_wr_sync_in),
        .sync_out(sync_out)
    );

    always begin
        // Toggle clock
        #1 clk = ~clk;
    end

    initial begin
        // Reset signals
        clk = 'b0;
        timestamp_every = 'h0;
        timestamp_wr_sync_in = 'b0;
        ext_wr_sync_in = 'b0;

        // Assert timestamp sync in
        timestamp_wr_sync_in = 'b1;
        #4;
        if (sync_out != 'b0) begin
            $error("Test FAILED, timestamp_wr_sync_in set reflected on sync_out");
        end

        // Deassert timestamp sync in
        timestamp_wr_sync_in = 'b0;
        #4;
        if (sync_out != 'b0) begin
            $error("Test FAILED, timestamp_wr_sync_in clear reflected on sync_out");
        end

        // Assert external sync in
        ext_wr_sync_in = 'b1;
        #4;
        if (sync_out != 'b1) begin
            $error("Test FAILED, wr_sync_in set not reflected on sync_out");
        end

        // Deassert external sync in
        ext_wr_sync_in = 'b0;
        #4;
        if (sync_out != 'b0) begin
            $error("Test FAILED, wr_sync_in clear not reflected on sync_out");
        end

        // Assert timestamp every
        timestamp_every = 'h4;

        // Assert external sync in
        ext_wr_sync_in = 'b1;
        #4;
        if (sync_out != 'b0) begin
            $error("Test FAILED, wr_sync_in set reflected on sync_out");
        end

        // Deassert external sync in
        ext_wr_sync_in = 'b0;
        #4;
        if (sync_out != 'b0) begin
            $error("Test FAILED, wr_sync_in clear reflected on sync_out");
        end

        // Assert timestamp sync in
        timestamp_wr_sync_in = 'b1;
        #4;
        if (sync_out != 'b1) begin
            $error("Test FAILED, timestamp_wr_sync_in set not reflected on sync_out");
        end

        // Deassert timestamp sync in
        timestamp_wr_sync_in = 'b0;
        #4;
        if (sync_out != 'b0) begin
            $error("Test FAILED, timestamp_wr_sync_in clear not reflected on sync_out");
        end

        // Got this far without error, all must be good
        $display("Test PASSED");

        // All done
        $finish;
    end;    

endmodule
