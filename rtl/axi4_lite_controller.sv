module axi4_lite_controller #( // slave controller
    parameter S_AXI_ADDR_WIDTH = 6,
    parameter S_AXI_DATA_WIDTH = 32
)(
    // Global signal
    input  logic                        ACLK,
    input  logic                        ARESETn,

    // Write Address (AW) channel ports
    input  logic [S_AXI_ADDR_WIDTH-1:0] AWADDR,
    input  logic                        AWVALID,
    output logic                        AWREADY,

    // Write Data (W) channel ports
    input  logic [S_AXI_DATA_WIDTH-1:0] WDATA,
    input  logic [1:0]                  WSTRB, // 2'b00: okay
    input  logic                        WVALID,
    output logic                        WREADY,

    // Write Response (B) channel ports
    output logic [1:0]                  BRESP,
    output logic                        BVALID,
    input  logic                        BREADY,

    // Read Address (AR) channel ports
    input  logic [S_AXI_ADDR_WIDTH-1:0] ARADDR,
    input  logic                        ARVALID,
    output logic                        ARREADY,

    // Read Data (R) channel ports
    output logic [S_AXI_DATA_WIDTH-1:0] RDATA,
    output logic [1:0]                  RRESP, // 2'b00: okay
    output logic                        RVALID,
    input  logic                        RREADY,

    // output ports for DDC_Top
    output logic                        ddc_enable,
    output logic [9:0]                  ddc_phase_word,

    // input ports from DDC_Top
    input logic                         ddc_x_o_ready,
    input logic                         ddc_y_o_ready
);

// controller internal register
logic [S_AXI_DATA_WIDTH-1:0] slv_reg0;
logic [S_AXI_DATA_WIDTH-1:0] slv_reg1;
logic [S_AXI_DATA_WIDTH-1:0] slv_reg2;
logic [S_AXI_DATA_WIDTH-1:0] slv_reg3;

// register address (byte addressing)
parameter slv_reg0_addr = 6'h00;
parameter slv_reg1_addr = 6'h04;
parameter slv_reg2_addr = 6'h08;
parameter slv_reg3_addr = 6'h12;

// ==============================================================
// 모든 Output 포트를 위한 내부 신호 선언 (RTL 표준 관례)
// ==============================================================
// 1. write signals
logic       awready;
logic       wready;
logic [1:0] bresp;
assign      bresp = 2'b00; // okay
logic       bvalid;

assign AWREADY = awready;
assign WREADY  = wready;
assign BRESP   = bresp;
assign BVALID  = bvalid;



// 2. read signals
logic                        arready;
logic [S_AXI_DATA_WIDTH-1:0] rdata;
logic [1:0]                  rresp;
assign                       rresp = 2'b00; // okay
logic                        rvalid;

assign ARREADY = arready;
assign RDATA   = rdata;
assign RRESP   = rresp;
assign RVALID  = rvalid;

// handshake
logic aw_hs; // AW channel handshake
assign aw_hs = awready & AWVALID;

logic w_hs; // W channel handshake
assign w_hs = wready & WVALID;

logic ar_hs; // AR channel handshake
assign ar_hs = arready & ARVALID;

logic r_hs; // R channel handshake
assign r_hs = rvalid & RREADY;

// write states
typedef enum logic [1:0] {WRIDLE, WRDATA, WRRESP} wstate_type;
wstate_type wpresent_state, wnext_state;

// read states
typedef enum logic {REIDLE, REDATA} rstate_type;
rstate_type rpresent_state, rnext_state;

// --------------------------------------------------------------
// 1. Write Transaction
// --------------------------------------------------------------
// state transition
always_ff @(posedge ACLK, negedge ARESETn) begin
    if(!ARESETn)
        wpresent_state <= WRIDLE;
    else    
        wpresent_state <= wnext_state;
end

always_comb begin
    awready = 1'b0;
    wready  = 1'b0;
    bvalid  = 1'b0;
    wnext_state = wpresent_state; // prevent latch

    case(wpresent_state) 
        WRIDLE: begin
            awready = 1'b1;
            if(AWVALID) wnext_state = WRDATA;
            else        wnext_state = WRIDLE;
        end

        WRDATA: begin
            wready = 1'b1;
            if(WVALID) wnext_state = WRRESP;
            else       wnext_state = WRDATA;
        end

        WRRESP: begin
            bvalid = 1'b1;
            if(BREADY) wnext_state = WRIDLE;
            else       wnext_state = WRRESP;
        end

        default: wnext_state = WRIDLE;
    endcase
end

// --------------------------------------------------------------
// 1-1. Write Operation
// --------------------------------------------------------------
logic [S_AXI_ADDR_WIDTH-1:0] awaddr_reg;
always_ff @(posedge ACLK, negedge ARESETn) begin
    if(!ARESETn)
        awaddr_reg <= '0;
    else if(aw_hs)
        awaddr_reg <= AWADDR;
end

always_ff @(posedge ACLK, negedge ARESETn) begin
    if(!ARESETn) begin
        slv_reg0 <= '0;
        slv_reg1 <= '0;
        slv_reg2 <= '0;
        slv_reg3 <= '0;
    end
    else begin
        if(w_hs && (wpresent_state == WRDATA)) begin
            case(awaddr_reg)
                slv_reg0_addr: begin
                    if(WSTRB[0]) slv_reg0[7:0]   <= WDATA[7:0];
                    if(WSTRB[1]) slv_reg0[15:8]  <= WDATA[15:8];
                    if(WSTRB[2]) slv_reg0[23:16] <= WDATA[23:16];
                    if(WSTRB[3]) slv_reg0[31:24] <= WDATA[31:24];
                end

                slv_reg1_addr: begin
                    if(WSTRB[0]) slv_reg1[7:0]   <= WDATA[7:0];
                    if(WSTRB[1]) slv_reg1[15:8]  <= WDATA[15:8];
                    if(WSTRB[2]) slv_reg1[23:16] <= WDATA[23:16];
                    if(WSTRB[3]) slv_reg1[31:24] <= WDATA[31:24];
                end

                slv_reg2_addr: begin
                    if(WSTRB[0]) slv_reg2[7:0]   <= WDATA[7:0];
                    if(WSTRB[1]) slv_reg2[15:8]  <= WDATA[15:8];
                    if(WSTRB[2]) slv_reg2[23:16] <= WDATA[23:16];
                    if(WSTRB[3]) slv_reg2[31:24] <= WDATA[31:24];
                end

                slv_reg3_addr: begin
                    if(WSTRB[0]) slv_reg3[7:0]   <= WDATA[7:0];
                    if(WSTRB[1]) slv_reg3[15:8]  <= WDATA[15:8];
                    if(WSTRB[2]) slv_reg3[23:16] <= WDATA[23:16];
                    if(WSTRB[3]) slv_reg3[31:24] <= WDATA[31:24];
                end
            endcase
        end
    end
end

// --------------------------------------------------------------
// 2. Read Transaction
// --------------------------------------------------------------
// state transition
always_ff @(posedge ACLK, negedge ARESETn) begin
    if(!ARESETn)
        rpresent_state <= REIDLE;
    else
        rpresent_state <= rnext_state;
end

always_comb begin
    arready = 1'b0;
    rvalid  = 1'b0;
    rnext_state = rpresent_state; // prevent latch

    case(rpresent_state) 
        REIDLE: begin
            arready = 1'b1;
            if(ARVALID) rnext_state = REDATA;
            else        rnext_state = REIDLE;
        end

        REDATA: begin
            rvalid = 1'b1;
            if(RREADY) rnext_state = REIDLE;
            else       rnext_state = REDATA;
        end

        default: rnext_state = REIDLE;
    endcase
end

// --------------------------------------------------------------
// 2-1. Read Operation
// --------------------------------------------------------------
logic [S_AXI_ADDR_WIDTH-1:0] araddr_reg;
always_ff @(posedge ACLK, negedge ARESETn) begin
    if(!ARESETn)
        araddr_reg <= '0;
    else if(ar_hs)
        araddr_reg <= ARADDR;
end

always_comb begin
    rdata = '0;
    if(r_hs && (rpresent_state == REDATA))
        case(araddr_reg)
            slv_reg0_addr: rdata = slv_reg0;
            slv_reg1_addr: rdata = slv_reg1;
            slv_reg2_addr: rdata = slv_reg2;
            slv_reg3_addr: rdata = slv_reg3;
            default:       rdata = '0;
        endcase
end

assign ddc_enable = slv_reg0[0];

assign ddc_phase_word = slv_reg1[9:0];

assign slv_reg2[0] = ddc_x_o_ready;
assign slv_reg2[1] = ddc_y_o_ready;

endmodule