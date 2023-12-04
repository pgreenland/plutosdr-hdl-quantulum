`timescale 1ns / 1ps

module util_wr_sync_mux(
    // Clock from sync_out domain
    input clk,

    // How often timestamping sub-system is inserting a timestamp
    input [31:0] timestamp_every,

    // FIFO write sync signal from timestamping sub-system
    input timestamp_wr_sync_in,

    // FIFO write sync signal from external source (to be used when timestamping disabled) 
    input ext_wr_sync_in,

    // FIFO write sync signal, from timestamping sub-system if enabled, otherwise external module
    output sync_out
);

    // Calculate when timestamping is enabled
    wire timestamp_en;
    assign timestamp_en = (timestamp_every != 0);

    wire timestamp_en_synced;

    // Synchronize timestamping enabled flag into sync_out clock domain
    cdc_sync_bits #(
        .NUM_BITS(1)
    ) sync_timestamp_en (
        .clk_out(clk),
        .reset('b0),
        .bits_in(timestamp_en),
        .bits_out(timestamp_en_synced)
    );

    wire ext_wr_sync_in_synced;

    // Synchronize external fifo write sync signal into sync_out clock domain
    cdc_sync_bits #(
        .NUM_BITS(1)
    ) sync_ext_wr_sync (
        .clk_out(clk),
        .reset('b0),
        .bits_in(ext_wr_sync_in),
        .bits_out(ext_wr_sync_in_synced)
    );

    // Select which sync signal to use
    assign sync_out = timestamp_en_synced ? timestamp_wr_sync_in : ext_wr_sync_in_synced;

endmodule
