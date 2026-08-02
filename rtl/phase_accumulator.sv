module phase_accumulator #(
    parameter WIDTH = 10
)(
    input  logic             clk,
    input  logic             n_rst,
    input  logic             en_i,
    input  logic [WIDTH-1:0] phase_word, // continuously incrementing phase angle
    output logic [WIDTH-1:0] z_o,
    output logic             done_o
);

logic [WIDTH-1:0] phase_reg;

always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        phase_reg <= '0;
        done_o    <= 1'b0;
    end
    else if(en_i) begin
        if(phase_reg + phase_word >= 10'd360) begin
            phase_reg <= (phase_reg + phase_word) - 10'd360;
        end
        else begin
            phase_reg <= phase_reg + phase_word;
        end
        done_o <= 1'b1;
    end
end

assign z_o = phase_reg;

endmodule