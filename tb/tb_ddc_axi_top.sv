module tb_ddc_axi_top;

    parameter S_AXI_ADDR_WIDTH = 6;
    parameter S_AXI_DATA_WIDTH = 32;

    // ========================================
    // input
    // ========================================
    logic                        ACLK;
    logic                        ARESETn;
    logic [S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
    logic                        s_axi_awvalid;
    logic [S_AXI_DATA_WIDTH-1:0] s_axi_wdata;
    logic [1:0]                  s_axi_wstrb;
    logic                        s_axi_wvalid;
    logic                        s_axi_bready;
    logic [S_AXI_ADDR_WIDTH-1:0] s_axi_araddr;
    logic                        s_axi_arvalid;
    logic                        s_axi_rready;

    logic signed [7:0]           adc_data;
    logic signed [7:0]           y_i;
    logic                        adc_valid; // high for every 15-clock

    assign y_i = '0;
    
    // ========================================
    // output
    // ========================================
    logic                        s_axi_awready;
    logic                        s_axi_wready;
    logic [1:0]                  s_axi_bresp;
    logic                        s_axi_bvalid;
    logic                        s_axi_arready;
    logic [S_AXI_DATA_WIDTH-1:0] s_axi_rdata;
    logic [1:0]                  s_axi_rresp;
    logic                        s_axi_rvalid;
                        
    logic signed [31:0]          ddc_x_o; // 16, 32, 64-bit
    logic signed [31:0]          ddc_y_o; // 16, 32, 64-bit

                        
    // clock
    initial begin
        ACLK = 1'b0;
    end

    always #5 ACLK = ~ACLK;

    // reset
    initial begin
        ARESETn = 1'b0;
    repeat(1) @(posedge ACLK);
        ARESETn = 1'b1;
    end

    // adc_valid
    logic [3:0] cnt;
    always_ff @(posedge ACLK, negedge ARESETn) begin
        if(!ARESETn) 
            cnt <= '0;
        else
            cnt <= cnt + 1'b1;
    end

    assign adc_valid = (cnt == 4'd15) ? 1'b1 : 1'b0; 

    // ===================================================
    // Read ADC sample data
    // ===================================================
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

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            sample_idx <= 0;
            adc_data   <= 8'sd0; 
        end
        else if (adc_valid) begin
            adc_data    <= adc_mem[sample_idx]; 
            sample_idx <= (sample_idx + 1) % 1024; 
        end
    end

    // ==============================================================
    // Task 1. Write 8'b0000_0001 to controller slv_reg0 - enable DDC
    // ==============================================================
    task enableDDC;
        begin
            s_axi_awaddr  = '0;
            s_axi_awvalid = 1'b0;
            s_axi_wdata   = '0;
            s_axi_wstrb   = '0;
            s_axi_wvalid  = 1'b0;
            s_axi_bready  = 1'b0;
            @(posedge ACLK);
            
            s_axi_awaddr  = 6'h00;
            s_axi_awvalid = 1'b1;
            s_axi_wdata   = 32'h1; // 1 = enable, 0 = disable
            s_axi_wstrb   = 4'b0001;
            s_axi_wvalid  = 1'b1;
            s_axi_bready  = 1'b1;
            @(posedge ACLK);

            wait(s_axi_awready == 1'b1);
            @(posedge ACLK);
            s_axi_awvalid = 1'b0;

            wait(s_axi_wready == 1'b1);
            @(posedge ACLK);
            s_axi_wvalid = 1'b0;

            wait(s_axi_bvalid == 1'b1);
            @(posedge ACLK);
            s_axi_bready = 1'b0;

            repeat(2) @(posedge ACLK);
        end
    endtask

    // ==========================================================================
    // Task 2. Write 10'b00000_01010 (10) to controller slv_reg1 - set phase_word
    // ==========================================================================
    task setPhaseWord;
        begin
            s_axi_awaddr  = '0;
            s_axi_awvalid = 1'b0;
            s_axi_wdata   = '0;
            s_axi_wstrb   = '0;
            s_axi_wvalid  = 1'b0;
            s_axi_bready  = 1'b0;
            @(posedge ACLK);

            s_axi_awaddr  = 6'h04;
            s_axi_awvalid = 1'b1;
            s_axi_wdata   = 32'd10; // 1 = enable, 0 = disable
            s_axi_wstrb   = 4'b0011;
            s_axi_wvalid  = 1'b1;
            s_axi_bready  = 1'b1;
            @(posedge ACLK);

            wait(s_axi_awready == 1'b1);
            @(posedge ACLK);
            s_axi_awvalid = 1'b0;

            wait(s_axi_wready == 1'b1);
            @(posedge ACLK);
            s_axi_wvalid = 1'b0;

            wait(s_axi_bvalid == 1'b1);
            @(posedge ACLK);
            s_axi_bready = 1'b0;

            repeat(2) @(posedge ACLK);
        end
    endtask

    // ===============================================================
    // Task 3. Write 8'b0000_0000 to controller slv_reg0 - disable DDC
    // ===============================================================
    task disableDDC;
        begin
            s_axi_awaddr  = '0;
            s_axi_awvalid = 1'b0;
            s_axi_wdata   = '0;
            s_axi_wstrb   = '0;
            s_axi_wvalid  = 1'b0;
            s_axi_bready  = 1'b0;
            @(posedge ACLK);

            s_axi_awaddr  = 6'h00;
            s_axi_awvalid = 1'b1;
            s_axi_wdata   = 32'h0; // 1 = enable, 0 = disable
            s_axi_wstrb   = 4'b0001;
            s_axi_wvalid  = 1'b1;
            s_axi_bready  = 1'b1;
            @(posedge ACLK);

            wait(s_axi_awready == 1'b1);
            @(posedge ACLK);
            s_axi_awvalid = 1'b0;

            wait(s_axi_wready == 1'b1);
            @(posedge ACLK);
            s_axi_wvalid = 1'b0;

            wait(s_axi_bvalid == 1'b1);
            @(posedge ACLK);
            s_axi_bready = 1'b0;

            repeat(2) @(posedge ACLK);
        end
    endtask


    initial begin
        enableDDC;

        setPhaseWord;

        repeat(10000) @(posedge ACLK); // control runtime
        disableDDC;
        $finish;
    end

    ddc_axi_top #(
        .S_AXI_ADDR_WIDTH   (S_AXI_ADDR_WIDTH),
        .S_AXI_DATA_WIDTH   (S_AXI_DATA_WIDTH)
    ) DDC_AXI_TOP(
        .ACLK               (ACLK),
        .ARESETn            (ARESETn),
        
        .s_axi_awaddr       (s_axi_awaddr),
        .s_axi_awvalid      (s_axi_awvalid),
        .s_axi_awready      (s_axi_awready),

        .s_axi_wdata        (s_axi_wdata),
        .s_axi_wstrb        (s_axi_wstrb),
        .s_axi_wvalid       (s_axi_wvalid),
        .s_axi_wready       (s_axi_wready),

        .s_axi_bresp        (s_axi_bresp),
        .s_axi_bvalid       (s_axi_bvalid),
        .s_axi_bready       (s_axi_bready),

        .s_axi_araddr       (s_axi_araddr),
        .s_axi_arvalid      (s_axi_arvalid),
        .s_axi_arready      (s_axi_arready),

        .s_axi_rdata        (s_axi_rdata),
        .s_axi_rresp        (s_axi_rresp),
        .s_axi_rvalid       (s_axi_rvalid),
        .s_axi_rready       (s_axi_rready),

        .adc_data           (adc_data),
        .y_i                (y_i),
        .ddc_x_o            (ddc_x_o),
        .ddc_y_o            (ddc_y_o),
        .adc_valid          (adc_valid)
    );

endmodule