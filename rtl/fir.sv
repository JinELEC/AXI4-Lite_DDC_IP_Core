module fir #(
    parameter N = 32, // 16, 32, 64
    parameter M = $clog2(N) // 4

    )(
    input  logic                clk,
    input  logic                n_rst,
    input  logic signed [N-1:0] in,
    input  logic                input_ready,
    output logic                output_ready,
    output logic signed [N-1:0] out
);

// Samples
typedef logic signed [15:0] sample_array;
sample_array samples [0:N-1];

// Filter coefficients (low-pass filter, 16-bit, Fs = 12.5 MHz, 0.04)
/* const sample_array coefficients [0:N-1] =
'{112,243,618,1293,2217,3225,4089,4587,4587,4089,3225,2217,1293,618,243,112}; */  // multiplied by 2^15 


// Filter coefficients (low-pass filter, 32-bit, 0.04) 
const sample_array coefficients [0:N-1] =
'{-54,-64,-82,-97,-93,-47,66,266,562,951,1412,1909,2396,2821,3136,3304,3304,3136,2821,2396,1909,1412,951,562,266,66,-47,-93,-97,-82,-64,-54}; 


// Filter coefficients (low-pass filter, 64-bit, 0.060) 
/* const sample_array coefficients [0:N-1] =
'{-12,-4,5,17,31,48,65,79,86,83,64,26,-31,-106,-194,-284,-366,-424,-442,-405,-300,-120,139,470,862,1295,1744,
2182,2578,2904,3137,3257,3257,3137,2904,2578,2182,1744,1295,862,470,139,-120,-300,-405,-442,-424,-366,-284,-194,
-106,-31,26,64,83,86,79,65,48,31,17,5,-4,-12}; */ 

// State
typedef enum logic [2:0] {IDLE, LOAD, PROCESS, ARRANGE, DONE} state_type;
state_type present_state;
state_type next_state;

// pipeline register
logic signed [N-1:0] reg_sample [0:3];
logic signed [15:0] reg_coefficient [0:3];

// address counter
logic unsigned [M:0] address; 

// sum
logic signed [2*N-1:0] sum;
logic signed [2*N-1:0] reg_sum1; // partial sum register
logic signed [2*N-1:0] reg_sum2; // partial sum register

// control signals
logic reset_accumulator;
logic load;
logic count;
logic partial_sum; // partial sum en
logic final_sum;   // final sum en

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
        arr_cnt <= 0;
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

logic signed [N-1:0] scaled_sum;
assign scaled_sum = $signed(sum) >>> (15);

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
    next_state        = present_state; // prevent latch

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
            count  = 1'b1;
            if(address > 0) partial_sum = 1'b1; 
            if(address > 4) final_sum = 1'b1;
            if(address == N-4) begin
                // count = 1'b0;
                next_state = ARRANGE;
            end
        end

        ARRANGE: begin // process remaining partial sum
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
            next_state = IDLE;
            end
        
        default: next_state = IDLE;
    endcase
end

endmodule
