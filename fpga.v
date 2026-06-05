module fpga (
    input wire                clk,
    input wire                rst,
    input wire               send,
    input wire [17:0]   switch_bus,

    output lcd
);

    wire [2:0]  opcode;
    wire [3:0]  dst;
    wire [15:0] out;

    cpu cpu0(
        .clk(clk),
        .rst(rst),
        .send(send),
        .switch_bus(switch_bus),

        .opcode(opcode),
        .dst(dst),
        .out(out)
    );

    // Fix display
    lcd_controller lcd_ctl0(
        .clk(clk),
        .reset(lcd),    // control unit
        .opcode(opcode),
        .registrador_destino(dst), // dst
        .valor_resultado(out) // data
    );

endmodule