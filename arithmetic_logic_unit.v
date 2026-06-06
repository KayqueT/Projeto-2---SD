module arithmetic_logic_unit (
    input wire        [1:0]  opcode,
    input wire signed [15:0]      a,
    input wire signed [15:0]      b,

    output reg signed [15:0]    out
);

    localparam [1:0]
        ADD = 2'b00,
        SUB = 2'b01,
        MUL = 2'b10;

    always @(*) begin
        case (opcode)
            ADD:    out = a + b;
            SUB:    out = a - b;
            MUL:    out = a * b;

            default: out = 16'h0000;
        endcase
    end
endmodule