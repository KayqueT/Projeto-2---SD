module cpu (
    input wire                  clk,
    input wire                  rst,
    input wire                 send,
    input wire [17:0]    switch_bus,

    output wire                 lcd,

    output wire  [2:0]       opcode,
    output wire  [3:0]          dst,
    output reg [15:0]           out
);

    // Maybe we should use it in header
    // opcodes
    localparam [2:0]
        LOAD    = 3'b000,
        ADD     = 3'b001,
        ADDI    = 3'b010,
        SUB     = 3'b011,
        SUBI    = 3'b100,
        MUL     = 3'b101,
        CLEAR   = 3'b110,
        DISPLAY = 3'b111;
    
    // ------ Control Unit --------

    // Control signals
    wire clear;
    wire write_enable;
    wire read_enable;
    wire alu_enable;
    wire lcd_enable;
    wire alu_imm;
    wire mem_imm;
    
    // Data signals
    //reg [2:0]  opcode;
    //reg [3:0]  dst;
    wire [3:0]  src0; 
    wire [3:0]  src1;
    wire [15:0] imm;

    // ----------- Memory --------------
    
    wire [15:0] mem_data_in;
    wire [15:0] mem_data_out;
    wire [15:0] read_data0;
    wire [15:0] read_data1;

    // --- Arithmetic and Logic Unit ---

    wire [15:0] alu_data_in;
    wire [15:0] alu_data_out;
    reg [1:0]  alu_opcode;
    
    assign mem_data_in = (mem_imm) ? imm : alu_data_out; // Verify if the data comes from ALU or imm
    assign alu_data_in = (alu_imm) ? imm : read_data1; // Verify if the data comes from reg or imm

    assign lcd = lcd_enable;

    always @(*) begin
        alu_opcode = 0;

        if (opcode == ADD ||
            opcode == ADDI)
        begin
            alu_opcode = 2'b00;
        end

        else if (opcode == SUB ||
                 opcode == SUBI)
        begin
            alu_opcode = 2'b01;
        end

        else if (opcode == MUL)
        begin
            alu_opcode = 2'b10;
        end
    end

    always @(*) begin
        out = 0;

        if (opcode == LOAD) out = imm;
        else if (opcode == DISPLAY) out = read_data0;
        else if (opcode != CLEAR) out = alu_data_out;
    end

    control_unit cu0 (
        .clk(clk),
        .rst(rst),
        .send(send),
        .switch_bus(switch_bus),
        
        .clear_mem(clear),
        .write_enable(write_enable),
        .read_enable(read_enable),
        .alu_enable(alu_enable),
        .lcd_enable(lcd_enable),
        .alu_imm(alu_imm),
        .mem_imm(mem_imm),
        .opcode(opcode),
        .dst(dst),
        .src0(src0),
        .src1(src1),
        .imm(imm)
    );

    memory mem0 (
        .clk(clk),
        .rst(clear),
        .write_enable(write_enable),
        .read_enable(read_enable),
        .write_addr(dst),
        .write_data(mem_data_in),
        .read_addr0(src0),
        .read_addr1(src1),

        .read_data0(read_data0),
        .read_data1(read_data1)
    );

    arithmetic_logic_unit alu0 (
        .opcode(alu_opcode),
        .a(read_data0),
        .b(alu_data_in),

        .out(alu_data_out)
    );

endmodule