module cordic(
    input  logic              clk,
    input  logic              n_rst,
    input  logic signed [7:0] x_i, // from ADC
    input  logic signed [7:0] y_i, // fix 0
    input  logic        [9:0] z_i, // target angle: 0 ~ 360
    input  logic              valid_i,
    output logic signed [7:0] x_o,
    output logic signed [7:0] y_o,
    output logic              done_o
);

logic [13:0] angle [0:7];

assign angle[0] = 14'd11520; // 45 * 2^8 
assign angle[1] = 14'd6801;  // 26.565 * 2^8
assign angle[2] = 14'd3593;  // 14.036 * 2^8
assign angle[3] = 14'd1824;  // 7.124  * 2^8
assign angle[4] = 14'd916;   // 3.576  * 2^8
assign angle[5] = 14'd458;   // 1.790  * 2^8
assign angle[6] = 14'd229;   // 0.896  * 2^8
assign angle[7] = 14'd115;   // 0.448  * 2^8

logic signed [17:0] z_i_180; 
assign z_i_180 = 18'd46080; // 180 * 2^8
logic signed [18:0] z_i_360;
assign z_i_360 = 19'd92160; // 360 * 2^8

// piepline register
logic signed [15:0] x [0:8];
logic signed [15:0] y [0:8];
logic signed [17:0] z [0:8];

// done flag 
logic done_flag [0:7];

// quadrant mapping
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        x[0]    <= '0;
        y[0]    <= '0;
        z[0]    <= '0;
    end
    else if(valid_i) begin
        if((0 <= z_i && z_i < 90))begin // 1st quadrant
            x[0] <= (x_i * 156); // 2^8 * 0.60726
            y[0] <= (y_i <<< 8); // 0
            z[0] <= (z_i <<< 8);
        end
        else if((90 <= z_i && z_i < 180)) begin // 2nd quadrant
            x[0] <= -(x_i * 156);
            y[0] <= -(y_i <<< 8);      
            z[0] <= -z_i_180 + (z_i <<< 8);
        end
        else if((180 <= z_i && z_i < 270)) begin // 3rd quadrant
            x[0] <= -(x_i * 156);
            y[0] <= -(y_i <<< 8);      
            z[0] <= -z_i_180 + (z_i <<< 8);
        end
        else if((270 <= z_i && z_i <= 360)) begin // 4th quadrant
            x[0] <= (x_i * 156);
            y[0] <= (y_i <<< 8);
         z[0] <= ((z_i <<< 8) - z_i_360);
        end
    end
end

always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) 
        done_flag[0] <= 1'b0;
    else
        done_flag[0] <= valid_i;
end
/* 
1. stage 1: >>> 0 -> 45도 좌표계에서 움직임
2. stage 2: >>> 1 -> 26.565도 좌표계에서 움직임
3. stage 3: >>> 2 -> 14.036도 좌표계에서 움직임
...
그래서 각 stage 마다 오른쪽으로 shift 하는 값을 다르게 해야 목표로 하는 target angle 에 수렴함.
*/

// ===========================================
// 1. Pipeline stage 1
// ===========================================
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        x[1] <= '0;
        y[1] <= '0;
        z[1] <= '0;
    end
    else if(z[0] >= 0) begin // z[0] > 0 -> rotate -45 degrees
        x[1] <= x[0] - (y[0] >>> 0); 
        y[1] <= y[0] + (x[0] >>> 0);
        z[1] <= z[0] - angle[0]; 
    end
    else begin // z[0] < 0 -> rotate +45 degrees
        x[1] <= x[0] + (y[0] >>> 0);
        y[1] <= y[0] - (x[0] >>> 0);
        z[1] <= z[0] + angle[0];
    end 
end

always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) 
        done_flag[1] <= 1'b0;
    else 
        done_flag[1] <= done_flag[0];
end

// ===========================================
// 2. Pipeline stage 2
// ===========================================
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        x[2] <= '0;
        y[2] <= '0;
        z[2] <= '0;
    end
    else if(z[1] >= 0) begin // z[1] > 0 -> rotate -26.565 degrees
        x[2] <= x[1] - (y[1] >>> 1);
        y[2] <= y[1] + (x[1] >>> 1);
        z[2] <= z[1] - angle[1];
    end
    else begin // z[1] < 0 -> rotate +26.565 degrees
        x[2] <= x[1] + (y[1] >>> 1);
        y[2] <= y[1] - (x[1] >>> 1);
        z[2] <= z[1] + angle[1];
    end 
end

always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) 
        done_flag[2] <= 1'b0;
    else 
        done_flag[2] <= done_flag[1];
end

// ===========================================
// 3. Pipeline stage 3
// ===========================================
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        x[3] <= '0;
        y[3] <= '0;
        z[3] <= '0;
    end
    else if(z[2] >= 0) begin // z[2] > 0 -> rotate -14.036 degrees
        x[3] <= x[2] - (y[2] >>> 2);
        y[3] <= y[2] + (x[2] >>> 2);
        z[3] <= z[2] - angle[2];
    end
    else begin // z[2] < 0 -> rotate +14.036 degrees
        x[3] <= x[2] + (y[2] >>> 2);
        y[3] <= y[2] - (x[2] >>> 2);
        z[3] <= z[2] + angle[2];
    end 
end

always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) 
        done_flag[3] <= 1'b0;
    else 
        done_flag[3] <= done_flag[2];
end

// ===========================================
// 4. Pipeline stage 4
// ===========================================
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        x[4] <= '0;
        y[4] <= '0;
        z[4] <= '0;
    end
    else if(z[3] >= 0) begin // z[3] > 0 -> rotate -7.124 degrees
        x[4] <= x[3] - (y[3] >>> 3);
        y[4] <= y[3] + (x[3] >>> 3);
        z[4] <= z[3] - angle[3];
    end
    else begin // z[3] < 0 -> rotate +7.124 degrees
        x[4] <= x[3] + (y[3] >>> 3);
        y[4] <= y[3] - (x[3] >>> 3);
        z[4] <= z[3] + angle[3];
    end 
end

always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) 
        done_flag[4] <= 1'b0;
    else
        done_flag[4] <= done_flag[3];
end
    
// ===========================================
// 5. Pipeline stage 5
// ===========================================
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        x[5] <= '0;
        y[5] <= '0;
        z[5] <= '0;
    end
    else if(z[4] >= 0) begin // z[4] > 0 -> rotate -3.576 degrees
        x[5] <= x[4] - (y[4] >>> 4);
        y[5] <= y[4] + (x[4] >>> 4);
        z[5] <= z[4] - angle[4];
    end
    else begin // z[4] < 0 -> rotate +3.576 degrees
        x[5] <= x[4] + (y[4] >>> 4);
        y[5] <= y[4] - (x[4] >>> 4);
        z[5] <= z[4] + angle[4];
    end
end

always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) 
        done_flag[5] <= 1'b0;
    else 
        done_flag[5] <= done_flag[4];
end

// ===========================================
// 6. Pipeline stage 6
// ===========================================
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        x[6] <= '0;
        y[6] <= '0;
        z[6] <= '0;
    end
    else if(z[5] >= 0) begin // z[5] > 0 -> rotate -1.790 degrees
        x[6] <= x[5] - (y[5] >>> 5);
        y[6] <= y[5] + (x[5] >>> 5);
        z[6] <= z[5] - angle[5];
    end
    else begin // z[5] < 0 -> rotate +1.790 degrees
        x[6] <= x[5] + (y[5] >>> 5);
        y[6] <= y[5] - (x[5] >>> 5);
        z[6] <= z[5] + angle[5];
    end
end

always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) 
        done_flag[6] <= 1'b0;
    else 
        done_flag[6] <= done_flag[5];
end

// ===========================================
// 7. Pipeline stage 7
// ===========================================
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        x[7] <= '0;
        y[7] <= '0;
        z[7] <= '0;
    end
    else if(z[6] >= 0) begin // z[6] > 0 -> rotate -0.896 degrees
        x[7] <= x[6] - (y[6] >>> 6);
        y[7] <= y[6] + (x[6] >>> 6);
        z[7] <= z[6] - angle[6];
    end
    else begin // z[6] < 0 -> rotate +0.896 degrees
        x[7] <= x[6] + (y[6] >>> 6);
        y[7] <= y[6] - (x[6] >>> 6);
        z[7] <= z[6] + angle[6];
    end
end

always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) 
        done_flag[7] <= 1'b0;
    else
        done_flag[7] <= done_flag[6];
end

// ===========================================
// 8. Pipeline stage 8
// ===========================================
always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) begin
        x[8] <= '0;
        y[8] <= '0;
        z[8] <= '0;
    end
    else if(z[7] >= 0) begin // z[6] > 0 -> rotate -0.448 degrees
        x[8] <= x[7] - (y[7] >>> 7);
        y[8] <= y[7] + (x[7] >>> 7);
        z[8] <= z[7] - angle[7];
    end
    else begin // z[6] < 0 -> rotate +0.448 degrees
        x[8] <= x[7] + (y[7] >>> 7);
        y[8] <= y[7] - (x[7] >>> 7);
        z[8] <= z[7] + angle[7];
    end
end

always_ff @(posedge clk, negedge n_rst) begin
    if(!n_rst) 
        done_o <= 1'b0;
    else 
        done_o <= done_flag[7];
end

assign x_o = (done_o == 1'b1) ? (x[8] >>> 8) : '0;
assign y_o = (done_o == 1'b1) ? (y[8] >>> 8) : '0;

endmodule