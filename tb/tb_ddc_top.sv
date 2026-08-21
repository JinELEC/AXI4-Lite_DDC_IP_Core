module tb_ddc_top;

    // input
    logic               clk;
    logic               n_rst;
    logic               en_i;
    logic        [9:0]  phase_word;
    logic signed [7:0]  x_i;
    logic signed [7:0]  y_i;
    
    // output
    logic signed [31:0] x_o; // 16, 32, 64-bit
    logic signed [31:0] y_o; // 16, 32, 64-bit
    logic               x_o_ready;
    logic               y_o_ready;

    assign y_i = '0;

    // clock
    initial begin
        clk = 1'b0;
    end

    always #5 clk = ~clk;

    // reset
    initial begin
        n_rst = 1'b0;
    repeat(1) @(posedge clk);
        n_rst = 1'b1;
    end

    // en_i
    logic [4:0] cnt;
    always_ff @(posedge clk, negedge n_rst) begin
        if(!n_rst) 
            cnt <= '0;
        else
            cnt <= cnt + 1'b1;
    end

    assign en_i = (cnt == 5'd31) ? 1'b1 : 1'b0; 

    // ==========================================
    // task for normal DDC operation
    // ==========================================
    task test1; // fix ADC input
        begin
        x_i = '0;
        phase_word = '0;

        @(posedge clk);

        x_i = 100;
        phase_word = 10; // low frequency
        repeat(3000) @(posedge clk);

        @(posedge clk);
        phase_word = 60; // high frequency
        repeat(3000) @(posedge clk);
    end
    endtask

    // Read ADC Samples from txt file
    logic signed [7:0] adc_mem [0:1023];
    integer sample_idx = 0;
    integer file_handle, scan_result, i;

    initial begin
        file_handle = $fopen("adc_samples.txt", "r");
        if(file_handle == 0) begin
            $display("File Open Error");
            $finish;
        end

        for(i = 0; i < 1024; i = i + 1) begin
                scan_result = $fscanf(file_handle, "%d\n", adc_mem[i]);
        end

        $fclose(file_handle);
    end

    // Apply ADC samples to DDC
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            sample_idx <= 0;
            x_i        <= 8'sd0; 
        end
        else if (en_i) begin
            x_i        <= adc_mem[sample_idx]; 
            sample_idx <= (sample_idx + 1) % 1024; 
        end
    end

    initial begin
        phase_word = '0;

        @(posedge clk);
        phase_word = 72; 
        repeat(40000) @(posedge clk);

        $fclose(fout);
        $fclose(cordic_file);
        $finish;
    end

    // ------------------------------------------------------
    // CORDIC output file
    // ------------------------------------------------------
    integer cordic_file;
    initial begin
        cordic_file = $fopen("cordic_out.txt", "w");

        if(cordic_file == 0) begin
            $display("CORDIC output file open error");
            $finish;
        end
    end

    always_ff @(posedge clk) begin
        if(en_i)
            $fdisplay(cordic_file, "%0d", DDC_TOP.wire_x);
    end

    // ------------------------------------------------------
    // FIR output file
    // ------------------------------------------------------
    integer fout;
    initial begin
        fout = $fopen("fir_out.txt", "w");

        if(fout == 0) begin
            $display("Output file open error");
            $finish;
        end
    end

    always_ff @(posedge clk) begin
    if(en_i)
        $fdisplay(fout, "%0d", x_o);
    end 

    ddc_top DDC_TOP(
        .clk            (clk),
        .n_rst          (n_rst),
        .en_i           (en_i),
        .phase_word     (phase_word),
        .x_i            (x_i),
        .y_i            (y_i),
        .x_o            (x_o),
        .y_o            (y_o),
        .x_o_ready      (x_o_ready),
        .y_o_ready      (y_o_ready)
    );

endmodule
