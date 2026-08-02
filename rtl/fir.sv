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
typedef logic signed [N-1:0] sample_array;
sample_array samples [0:N-1];

// Filter coefficients (low-pass filter, 16-bit, Fs = 12.5 MHz, 0.04)
/* const sample_array coefficients [0:N-1] =
'{282,439,879,1548,2338,3111,3724,4063,4063,3724,3111,2338,1548,879,439,282}; */  // multiplied by 2^15 


// Filter coefficients (low-pass filter, 32-bit, 0.04) 
const sample_array coefficients [0:N-1] =
'{5395358,6715351,9690213,14611338,21637088,30769064,41840389,54517449,68315382,82626469,96759400,109986470,121595002,
130938884,137486035,140857934,140857934,137486035,130938884,121595002,109986470,96759400,82626469,68315382,54517449,
41840389,30769064,21637088,14611338,9690213,6715351,5395358}; 


// Filter coefficients (low-pass filter, 64-bit, 0.060) 
/* const sample_array coefficients [0:N-1] = 
'{-64'd2517888347906280,-64'd4019496189917589,-64'd5847306912785929,-64'd8149899774532560,-64'd11011638882067694,-64'd14426070343383746,-64'd18274761416243772,
-64'd22313799891024340,-64'd26169697726587148,-64'd29345815274292008,-64'd31239682857640960,-64'd31170796063466680,-64'd28417656792131272,-64'd22262082705900368,
-64'd12038169582469022,64'd2817185993343596,64'd22715572759805036,64'd47873579014966696,64'd78277767497056192,64'd113660926060685392,64'd153491784014500704,
64'd196979588706981376,64'd243094022315592224,64'd290599964790769024,64'd338105640747283840,64'd384121791706661376,64'd427128752478699968,64'd465647735309172608,
64'd498312279223282368,64'd523935731075439424,64'd541570798327476928,64'd550557642738632960,64'd550557642738632960,64'd541570798327476928,64'd523935731075439424,
64'd498312279223282368,64'd465647735309172608,64'd427128752478699968,64'd384121791706661376,64'd338105640747283840,64'd290599964790769024,64'd243094022315592224,
64'd196979588706981376,64'd153491784014500704,64'd113660926060685392,64'd78277767497056192,64'd47873579014966696,64'd22715572759805036,64'd2817185993343596,
-64'd12038169582469022,-64'd22262082705900368,-64'd28417656792131272,-64'd31170796063466680,-64'd31239682857640960,-64'd29345815274292008,-64'd26169697726587148,
-64'd22313799891024340,-64'd18274761416243772,-64'd14426070343383746,-64'd11011638882067694,-64'd8149899774532560,-64'd5847306912785929,-64'd4019496189917589,
-64'd2517888347906280}; */

// State
typedef enum logic [2:0] {IDLE, LOAD, PROCESS, ARRANGE, DONE} state_type;
state_type present_state;
state_type next_state;

// pipeline register
logic signed [N-1:0] reg_sample [0:3];
logic signed [N-1:0] reg_coefficient [0:3];

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
assign scaled_sum = $signed(sum) >>> (N-1);

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