module lcd_formatter (
    input  wire        clk,
    input  wire        rst,
    input  wire        update_trigger,
    input  wire [2:0]  opcode,
    input  wire [3:0]  dst,
    input  wire [15:0] data, 
    input  wire        next_char_req,

    output wire [7:0]  char_data,
    output reg         char_valid
);

    localparam 
        IDLE = 0, 
        LATCH = 1, 
        SEND = 2;
    
    localparam [2:0]
        LOAD    = 3'b000,
        ADD     = 3'b001,
        ADDI    = 3'b010,
        SUB     = 3'b011,
        SUBI    = 3'b100,
        MUL     = 3'b101,
        CLEAR   = 3'b110,
        DISPLAY = 3'b111;

    reg [1:0] state;
    reg [4:0] char_index;

    reg [2:0] latched_op;
    reg [3:0] latched_dst;
    reg [15:0] latched_res;

    reg [15:0] abs_val;
    reg [19:0] bcd;
    
    reg [3:0] dst_tens;
    reg [3:0] dst_ones;
    
    integer i;

    always @(*) begin
        abs_val = latched_res[15] ? (~latched_res + 1'b1) : latched_res;
        bcd = 0;
        for (i = 15; i >= 0; i = i - 1) begin
            if (bcd[3:0] >= 5) bcd[3:0] = bcd[3:0] + 3;
            if (bcd[7:4] >= 5) bcd[7:4] = bcd[7:4] + 3;
            if (bcd[11:8] >= 5) bcd[11:8] = bcd[11:8] + 3;
            if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
            if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
            bcd = {bcd[18:0], abs_val[i]};
        end

        if (latched_dst >= 10) begin
            dst_tens = 1;
            dst_ones = latched_dst - 10;
        end else begin
            dst_tens = 0;
            dst_ones = latched_dst;
        end
    end

    reg [7:0] screen [0:31];
    integer k;

    assign char_data = screen[char_index];

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            char_index <= 0;
            char_valid <= 0;
            for (k = 0; k < 32; k = k + 1) screen[k] <= 8'h20; 
        end else begin
            case (state)
                IDLE: begin
                    char_valid <= 0;
                    char_index <= 0;
                    if (update_trigger) begin
                        latched_op <= opcode;
                        latched_dst <= dst;
                        latched_res <= data;
                        state <= LATCH;
                    end
                end
                
                LATCH: begin
                    for (k = 0; k < 32; k = k + 1) screen[k] <= 8'h20;

                    if (latched_op == CLEAR) begin
                        screen[0] <= 8'h43; // C
                        screen[1] <= 8'h4C; // L
                        screen[2] <= 8'h45; // E
                        screen[3] <= 8'h41; // A
                        screen[4] <= 8'h52; // R
                    end
                    else begin
                        screen[26] <= latched_res[15] ? 8'h2D : 8'h2B;
                        screen[27] <= 8'h30 + bcd[19:16];
                        screen[28] <= 8'h30 + bcd[15:12];
                        screen[29] <= 8'h30 + bcd[11:8];
                        screen[30] <= 8'h30 + bcd[7:4];
                        screen[31] <= 8'h30 + bcd[3:0];

                        screen[6]  <= 8'h5B; // [
                        screen[7]  <= 8'h30 + dst_tens;
                        screen[8]  <= 8'h30 + dst_ones;
                        screen[9]  <= 8'h5D; // ]
                        screen[10] <= 8'h5B; // [
                        screen[11] <= latched_dst[3] ? 8'h31 : 8'h30;
                        screen[12] <= latched_dst[2] ? 8'h31 : 8'h30;
                        screen[13] <= latched_dst[1] ? 8'h31 : 8'h30;
                        screen[14] <= latched_dst[0] ? 8'h31 : 8'h30;
                        screen[15] <= 8'h5D; // ]

                        if (latched_op == DISPLAY) begin
                            screen[0] <= 8'h44; // D
                            screen[1] <= 8'h49; // I
                            screen[2] <= 8'h53; // S
                            screen[3] <= 8'h50; // P
                        end
                        else begin
                            case (latched_op)
                                LOAD: begin screen[0]<=8'h4C; screen[1]<=8'h4F; screen[2]<=8'h41; screen[3]<=8'h44; end
                                ADD:  begin screen[0]<=8'h41; screen[1]<=8'h44; screen[2]<=8'h44; end
                                ADDI: begin screen[0]<=8'h41; screen[1]<=8'h44; screen[2]<=8'h44; screen[3]<=8'h49; end
                                SUB:  begin screen[0]<=8'h53; screen[1]<=8'h55; screen[2]<=8'h42; end
                                SUBI: begin screen[0]<=8'h53; screen[1]<=8'h55; screen[2]<=8'h42; screen[3]<=8'h49; end
                                MUL:  begin screen[0]<=8'h4D; screen[1]<=8'h55; screen[2]<=8'h4C; end
                                default: begin screen[0]<=8'h3F; screen[1]<=8'h3F; screen[2]<=8'h3F; end
                            endcase
                        end
                    end
                    
                    state <= SEND;
                    char_valid <= 1;
                end
                
                SEND: begin
                    if (next_char_req) begin
                        if (char_index == 31) begin
                            state <= IDLE;
                            char_valid <= 0;
                        end else begin
                            char_index <= char_index + 1;
                        end
                    end
                end
            endcase
        end
    end
endmodule