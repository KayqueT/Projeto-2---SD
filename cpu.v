module cpu (
    input wire                  clk,
    input wire                  rst,
    input wire                 send,
    input wire [17:0]    switch_bus

);
    
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
    wire [2:0]  opcode;
    wire [3:0]  dst;
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
    
    assign mem_data_in = (mem_imm) ? imm : alu_data_out; // Verify if the data comes from ALU or imm
    assign alu_data_in = (alu_imm) ? imm : read_data1; // Verify if the data comes from reg or imm

    control_unit cu0 (
        .clk(clk),
        .rst(rst),
        .send(send),
        .switch_bus(switch_bus),
        
        .clear(clear),
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
        .opcode(opcode),
        .a(read_data0),
        .b(alu_data_in),

        .out(alu_data_out)
    );

endmodule