module ddc_top(
    input  logic               clk,
    input  logic               n_rst,
    input  logic               en_i,
    input  logic        [9:0]  phase_word,
    input  logic signed [7:0]  x_i, // from ADC
    input  logic signed [7:0]  y_i, // fix 0
    output logic signed [31:0] x_o, // 16, 32, 64-bit
    output logic signed [31:0] y_o,
    output logic               x_o_ready,
    output logic               y_o_ready
);

// wire between phase_accumulator & cordic
logic [9:0] wire_z;
logic       wire_done;

// wires between cordic & fir
logic signed [7:0] wire_x;
logic signed [7:0] wire_y;

logic signed [31:0] wire_x_in; // 16, 32, 64-bit
logic signed [31:0] wire_y_in; // 16, 32, 64-bit
assign wire_x_in = { {24{wire_x[7]}}, wire_x }; 
assign wire_y_in = { {24{wire_y[7]}}, wire_y };

phase_accumulator PHASE_ACCUMULATOR(
    .clk            (clk),
    .n_rst          (n_rst),
    .en_i           (en_i),
    .phase_word     (phase_word),
    .z_o            (wire_z),
    .done_o         (wire_done)
);

cordic CORDIC(
    .clk            (clk),
    .n_rst          (n_rst),
    .x_i            (x_i),
    .y_i            (y_i),
    .z_i            (wire_z),
    .valid_i        (wire_done),
    .x_o            (wire_x),
    .y_o            (wire_y),
    .done_o         (wire_input_ready)
);

fir FIRX(
    .clk            (clk),
    .n_rst          (n_rst),
    .in             (wire_x_in),
    .input_ready    (wire_input_ready),
    .output_ready   (x_o_ready),
    .out            (x_o)
);

fir FIRY(
    .clk            (clk),
    .n_rst          (n_rst),
    .in             (wire_y_in),
    .input_ready    (wire_input_ready),
    .output_ready   (y_o_ready),
    .out            (y_o)
);

endmodule