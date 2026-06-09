module lcd_driver (
    input wire clk,
    input wire rst,
    input wire [7:0] char_data,
    input wire char_valid,

    output reg [7:0] lcd_data,
    output reg lcd_rs,
    output reg lcd_rw,
    output reg lcd_en,
    output wire lcd_on,
    output wire lcd_blon,
    output reg next_char_req
);

    assign lcd_on = ~rst;
    assign lcd_blon = ~rst;

    localparam TIME_INIT = 2_500_000;
    localparam TIME_CMD  = 100_000;

    localparam [3:0] 
        S_INIT_WAIT=0, 
        S_INIT_CMD=1, 
        S_IDLE=2, 
        S_POS_L1=3, 
        S_WRITE_L1=4, 
        S_POS_L2=5, 
        S_WRITE_L2=6, 
        S_PULSE=7, 
        S_PULSE_WAIT=8;

    reg [3:0] state;
    reg [3:0] return_state;
    reg [21:0] cnt;
    reg [2:0] init_idx;
    reg [4:0] char_idx;

    reg [7:0] init_cmds [0:3];
    
    initial begin
        init_cmds[0] = 8'h38;
        init_cmds[1] = 8'h0C;
        init_cmds[2] = 8'h01;
        init_cmds[3] = 8'h06;
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= S_INIT_WAIT;
            cnt <= 0;
            init_idx <= 0;
            char_idx <= 0;
            lcd_data <= 0;
            lcd_rs <= 0;
            lcd_rw <= 0;
            lcd_en <= 0;
            next_char_req <= 0;
        end else begin
            next_char_req <= 0;
            
            case (state)
                S_INIT_WAIT: begin
                    if (cnt < TIME_INIT) cnt <= cnt + 1;
                    else begin cnt <= 0; state <= S_INIT_CMD; end
                end
                
                S_INIT_CMD: begin
                    lcd_rs <= 0;
                    lcd_rw <= 0;
                    lcd_data <= init_cmds[init_idx];
                    return_state <= (init_idx == 3) ? S_IDLE : S_INIT_CMD;
                    if (init_idx < 3) init_idx <= init_idx + 1;
                    state <= S_PULSE;
                end
                
                S_IDLE: begin
                    char_idx <= 0;
                    if (char_valid) state <= S_POS_L1;
                end
                
                S_POS_L1: begin
                    lcd_rs <= 0; 
                    lcd_data <= 8'h80;
                    return_state <= S_WRITE_L1;
                    state <= S_PULSE;
                end
                
                S_WRITE_L1: begin
                    lcd_rs <= 1; 
                    lcd_data <= char_data;
                    next_char_req <= 1;
                    char_idx <= char_idx + 1;
                    return_state <= (char_idx == 15) ? S_POS_L2 : S_WRITE_L1;
                    state <= S_PULSE;
                end
                
                S_POS_L2: begin
                    lcd_rs <= 0; 
                    lcd_data <= 8'hC0;
                    return_state <= S_WRITE_L2;
                    state <= S_PULSE;
                end
                
                S_WRITE_L2: begin
                    lcd_rs <= 1; 
                    lcd_data <= char_data;
                    next_char_req <= 1;
                    char_idx <= char_idx + 1;
                    return_state <= (char_idx == 31) ? S_IDLE : S_WRITE_L2;
                    state <= S_PULSE;
                end
                
                S_PULSE: begin
                    lcd_en <= 1;
                    if (cnt < 50) cnt <= cnt + 1;
                    else begin cnt <= 0; lcd_en <= 0; state <= S_PULSE_WAIT; end
                end
                
                S_PULSE_WAIT: begin
                    if (cnt < TIME_CMD) cnt <= cnt + 1;
                    else begin cnt <= 0; state <= return_state; end
                end
            endcase
        end
    end
endmodule