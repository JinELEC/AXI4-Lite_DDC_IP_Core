module ddc_axi_top #(
    parameter S_AXI_ADDR_WIDTH = 6,
    parameter S_AXI_DATA_WIDTH = 32
)(
    // Global signal 
    input logic                         ACLK,
    input logic                         ARESETn,

    // ================================================
    // AXI4-Lite Interface
    // ================================================
    // Write Address (AW) channel ports
    input  logic [S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic                        s_axi_awvalid,
    output logic                        s_axi_awready,

    // Write Data (W) channel ports
    input  logic [S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [1:0]                  s_axi_wstrb, // 2'b00: okay
    input  logic                        s_axi_wvalid,
    output logic                        s_axi_wready,

    // Write Response (B) channel ports
    output logic [1:0]                  s_axi_bresp,
    output logic                        s_axi_bvalid,
    input  logic                        s_axi_bready,

    // Read Address (AR) channel ports
    input  logic [S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic                        s_axi_arvalid,
    output logic                        s_axi_arready,

    // Read Data (R) channel ports
    output logic [S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]                  s_axi_rresp, // 2'b00: okay
    output logic                        s_axi_rvalid,
    input  logic                        s_axi_rready,

    // ================================================
    // DDC interface
    // ================================================
    input  logic signed [7:0]           adc_data,   // from ADC
    input  logic signed [7:0]           y_i,        // fix 0

    output logic signed [31:0]          ddc_x_o,    // 16, 32, 64-bit
    output logic signed [31:0]          ddc_y_o,    // 16, 32, 64-bit

    // ================================================
    // ADC interface
    // ================================================
    input  logic                        adc_valid 
);

// wires between axi4_lite_controller & DDC
logic       ddc_enable; 

logic       wire_enable;
assign wire_enable = ddc_enable & adc_valid; // ddc_enable from slv_reg[0] & adc_valid from ADC

logic [9:0] wire_phase_word;
logic       wire_x_o_ready;
logic       wire_y_o_ready;

// AXI4-Lite controller instantiation
axi4_lite_controller #(
    .S_AXI_ADDR_WIDTH(S_AXI_ADDR_WIDTH),
    .S_AXI_DATA_WIDTH(S_AXI_DATA_WIDTH)
) AXI4_LITE_CONTROLLER (
    .ACLK           (ACLK),
    .ARESETn        (ARESETn),
    
    .AWADDR         (s_axi_awaddr),
    .AWVALID        (s_axi_awvalid),                       
    .AWREADY        (s_axi_awready),
    
    .WDATA          (s_axi_wdata),
    .WSTRB          (s_axi_wstrb),
    .WVALID         (s_axi_wvalid),
    .WREADY         (s_axi_wready),

    .BRESP          (s_axi_bresp),
    .BVALID         (s_axi_bvalid),
    .BREADY         (s_axi_bready),

    .ARADDR         (s_axi_araddr),
    .ARVALID        (s_axi_arvalid),
    .ARREADY        (s_axi_arready),

    .RDATA          (s_axi_rdata),
    .RRESP          (s_axi_rresp),
    .RVALID         (s_axi_rvalid),
    .RREADY         (s_axi_rready),

    .ddc_enable     (ddc_enable),
    .ddc_phase_word (wire_phase_word),
    .ddc_x_o_ready  (wire_x_o_ready),
    .ddc_y_o_ready  (wire_y_o_ready)
);

// DDC top instantiation
ddc_top DDC_TOP(
    .clk            (ACLK),
    .n_rst          (ARESETn),
    .en_i           (wire_enable),
    .phase_word     (wire_phase_word),
    .x_i            (adc_data),
    .y_i            (y_i),
    .x_o            (ddc_x_o),
    .y_o            (ddc_y_o),
    .x_o_ready      (wire_x_o_ready),
    .y_o_ready      (wire_y_o_ready)
);

endmodule