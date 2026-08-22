module fir #(
    parameter N = 32, // 16, 32, 64
    parameter M = $clog2(N) // 4
)(
    input  logic                   clk,
    input  logic                   n_rst,
    input  logic signed [N-1:0]    in,
    input  logic                   input_ready,
    output logic                   output_ready,
    output logic signed [N-1:0]    out
);

// Samples
typedef logic signed [N-1:0] sample_array;
sample_array samples [0:N-1];

typedef logic signed [15:0] coeff_array;

// Filter coefficients
// 16-tap
/* const coeff_array coefficients [0:N-1] =
'{-42,-177,-406,-352,669,2961,5846,7885,7885,5846,2961,669,-352,-406,-177,-42}; */

// 32-tap 
const coeff_array coefficients [0:N-1] =
'{-21,-60,-84,-52,78,273,387,221,-301,-974,-1305,-731,1017,3642,6306,7987,7987,6306,3642,1017,-731,-1305,-974,-301,221,387,273,78,-52,-84,-60,-21}; 

// 64-tap 
/* const coeff_array coefficients [0:N-1] = 
'{-10,-26,-29,-14,17,50,61,31,-37,-109,-130,-64,76,217,254,123,-142,-398,-459,-220,254,708,822,397,-468,-1347,-1637,-848,1111,3807,6403,7994,7994,6403,3807,1111,-848,-1637,-1347,-468,397,822,708,254,-220,-459,-398,-142,123,254,217,76,-64,-130,-109,-37,31,61,50,17,-14,-29,-26,-10}; */

// State
typedef enum logic [2:0] {IDLE, LOAD, PROCESS, ARRANGE, DONE} state_type;
state_type present_state;
state_type next_state;

// pipeline register
logic signed [N-1:0]  reg_sample [0:3];
logic signed [15:0]   reg_coefficient [0:3]; 

// address counter
logic unsigned [M:0] address; 

// sum
logic signed [N+22:0] sum;
logic signed [N+22:0] reg_sum1;
logic signed [N+22:0] reg_sum2;

// control signals
logic reset_accumulator;
logic load;
logic count;
logic partial_sum;
logic final_sum;

// samples 
always_ff @(posedge clk) begin
    if(load) begin
        for(int i = N-1; i >= 1; i--) begin
            samples[i] <= samples[i-1];
        end
        samples[0] <= in;
    end
end

// address
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst)
        address <= '0;
    else if(reset_accumulator)
        address <= '0;
    else if(count)
        address <= address + 4;
end

// Arrange state counter
logic arr_cnt;
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) 
        arr_cnt <= 1'b0;
    else if(present_state == ARRANGE)
        arr_cnt <= 1'b1;
    else 
        arr_cnt <= 1'b0;
end    

// --------------------------------------------------
// 1. Stage 1: Fetch
// --------------------------------------------------
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        reg_sample[0]      <= '0;
        reg_sample[1]      <= '0;
        reg_sample[2]      <= '0;
        reg_sample[3]      <= '0;
        reg_coefficient[0] <= '0;
        reg_coefficient[1] <= '0;
        reg_coefficient[2] <= '0;
        reg_coefficient[3] <= '0;
    end
    else if(count) begin
        reg_sample[0]      <= samples[address];
        reg_sample[1]      <= samples[address + 1];
        reg_sample[2]      <= samples[address + 2];
        reg_sample[3]      <= samples[address + 3];
        reg_coefficient[0] <= coefficients[address];
        reg_coefficient[1] <= coefficients[address + 1];
        reg_coefficient[2] <= coefficients[address + 2];
        reg_coefficient[3] <= coefficients[address + 3];
    end
end

// --------------------------------------------------
// 2. Stage 2: Partial sum
// --------------------------------------------------
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        reg_sum1 <= '0;
        reg_sum2 <= '0;
    end
    else if(reset_accumulator) begin
        reg_sum1 <= '0;
        reg_sum2 <= '0;
    end
    else if(partial_sum) begin
        reg_sum1 <= (reg_sample[0] * reg_coefficient[0]) + (reg_sample[1] * reg_coefficient[1]);
        reg_sum2 <= (reg_sample[2] * reg_coefficient[2]) + (reg_sample[3] * reg_coefficient[3]);
    end
end

// --------------------------------------------------
// 3. Stage 3: Final sum
// --------------------------------------------------
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) 
        sum <= '0;
    else if(reset_accumulator) 
        sum <= '0;
    else if(final_sum)
        sum <= sum + reg_sum1 + reg_sum2;
end

// Output shift
logic signed [N-1:0] scaled_sum;
assign scaled_sum = (N)'($signed(sum) >>> 15);

// output
always_ff @(posedge clk) begin
    if(output_ready)
        out <= scaled_sum;
end

// State transition
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst)
        present_state <= IDLE;
    else
        present_state <= next_state;
end

// Controller
always_comb begin
    reset_accumulator = 1'b0;
    load              = 1'b0;
    count             = 1'b0;
    partial_sum       = 1'b0;
    final_sum         = 1'b0;
    output_ready      = 1'b0;
    next_state        = present_state;

    case(present_state)
        IDLE: begin
            reset_accumulator = 1'b1;
            if(input_ready) next_state = LOAD;
        end

        LOAD: begin
            load = 1'b1;
            reset_accumulator = 1'b1;
            next_state = PROCESS;
        end

        PROCESS: begin
            count = 1'b1;
            if(address > 0) partial_sum = 1'b1; 
            if(address > 4) final_sum = 1'b1;
            if(address == N-4) begin
                next_state = ARRANGE;
            end
        end

        ARRANGE: begin
            partial_sum = 1'b1;
            final_sum   = 1'b1;
            if(arr_cnt) begin
                partial_sum = 1'b0;
                final_sum   = 1'b1;
                next_state  = DONE;
            end
        end

        DONE: begin
            output_ready = 1'b1;
            next_state   = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule
