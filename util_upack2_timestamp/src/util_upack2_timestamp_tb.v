`timescale 1ns / 1ps

module util_upack2_timestamp_tb;
    reg clk;
    reg reset;
    reg [63:0] timestamp;
    reg [31:0] timestamp_every;
    reg enable_0;
    reg enable_1;
    reg enable_2;
    reg enable_3;
    reg fifo_rd_en;
    wire fifo_rd_valid;
    wire fifo_rd_underflow;
    wire [15:0] fifo_rd_data_0;
    wire [15:0] fifo_rd_data_1;
    wire [15:0] fifo_rd_data_2;
    wire [15:0] fifo_rd_data_3;
    reg s_axis_valid;
    wire s_axis_ready;
    reg s_axis_xfer_req;
    reg [127:0] s_axis_data;

    util_upack2_timestamp #( 
        .NUM_OF_CHANNELS (4),
        .SAMPLE_DATA_WIDTH (16),
        .SAMPLES_PER_CHANNEL (1)
    ) uut (
        .clk(clk),
        .reset(reset),
        .timestamp(timestamp),
        .timestamp_every(timestamp_every),
        .enable_0(enable_0),
        .enable_1(enable_1),
        .enable_2(enable_2),
        .enable_3(enable_3),
        .fifo_rd_en(fifo_rd_en),
        .fifo_rd_valid(fifo_rd_valid),
        .fifo_rd_underflow(fifo_rd_underflow),
        .fifo_rd_data_0(fifo_rd_data_0),
        .fifo_rd_data_1(fifo_rd_data_1),
        .fifo_rd_data_2(fifo_rd_data_2),
        .fifo_rd_data_3(fifo_rd_data_3),
        .s_axis_valid(s_axis_valid),
        .s_axis_ready(s_axis_ready),
        .s_axis_xfer_req(s_axis_xfer_req),
        .s_axis_data(s_axis_data)
    );

    always begin
        // Toggle clock
        #1 clk = ~clk;
    end

    // Enable values
    reg [3:0] enables [0:14];

    initial begin
        // Prepare enables
        enables[0] = 'b0001;
        enables[1] = 'b0010;
        enables[2] = 'b0100;
        enables[3] = 'b1000;
        enables[4] = 'b0011;
        enables[5] = 'b0110;
        enables[6] = 'b1100;
        enables[7] = 'b0101;
        enables[8] = 'b1010;
        enables[9] = 'b1001;
        enables[10] = 'b1110;
        enables[11] = 'b1101;
        enables[12] = 'b1011;
        enables[13] = 'b0111;
        enables[14] = 'b1111;
    end      

    integer k;

    initial begin
        // Reset signals
        clk = 'b0;
        reset = 'b1;
        timestamp = 'h0;
        timestamp_every = 'h0;
        enable_0 = 'b0;
        enable_1 = 'b0;
        enable_2 = 'b0;
        enable_3 = 'b0;
        fifo_rd_en = 'b0;
        s_axis_valid = 'h0;
        s_axis_xfer_req = 'b1;
        s_axis_data = 'h0;

        // De-assert reset
        #3
        reset = 1'b0;

        // Perform test sequence a couple of times
        for (integer i = 0; i < 1; i = i + 1) begin
            // Iterate through enables
            for (integer j = 0; j < 15; j = j + 1) begin
                // Assert enables
                {enable_0, enable_1, enable_2, enable_3} <= enables[j];
    
                // Reset module after changing enables
                reset <= 1'b1;
                #2;
                reset <= 1'b0;
                #4;
    
                // Begin reading data
                fifo_rd_en <= 'b1;
    
                k = 0;
                while (k < 48) begin
                    // Provide data on first step, or if ready asserted
                    if (k == 0 || s_axis_ready == 'b1) begin
                        // Provide record
                        s_axis_data[112+:16] = k+8;
                        s_axis_data[96+:16] = k+7;
                        s_axis_data[80+:16] = k+6;
                        s_axis_data[64+:16] = k+5;
                        s_axis_data[48+:16] = k+4;
                        s_axis_data[32+:16] = k+3;
                        s_axis_data[16+:16] = k+2;
                        s_axis_data[0+:16] = k+1;
                        s_axis_valid = 'b1;

                        // Increment index   
                        k = k + 8;
                    end
                    
                    // Delay for clock cycle
                    #2;
                end

                // Delay for final output
                case (enables[j][0] + enables[j][1] + enables[j][2] + enables[j][3])
                    1: #18;
                    2: #6;
                    3: #4;
                endcase

                // Stop reading data
                s_axis_valid <= 'b0;
                fifo_rd_en <= 'b0;
                #2;

                // Delay before aserting next enables
                #2;
            end
        end

        // Wait few final cycles
        #2;

        // All done
        $finish;
    end
   
    // Wait for the rising edge of enable signal and print data
    always @(posedge clk) begin
        if (fifo_rd_valid == 'b1) begin
            if (enable_0 == 'b1) $display("Output0: %h", fifo_rd_data_0);
            if (enable_1 == 'b1) $display("Output1: %h", fifo_rd_data_1);
            if (enable_2 == 'b1) $display("Output2: %h", fifo_rd_data_2);
            if (enable_3 == 'b1) $display("Output3: %h", fifo_rd_data_3);
        end
    end
endmodule
