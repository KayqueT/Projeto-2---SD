module memory (
    input wire                clk,
    input wire                rst, // clear
    input wire       write_enable,
    input wire        read_enable,
    input wire [3:0]   write_addr,
    input wire [15:0]  write_data,
    input wire [3:0]   read_addr0,
    input wire [3:0]   read_addr1,
    
    output reg [15:0]  read_data0,
    output reg [15:0]  read_data1
);

    localparam 
        NUM_REG  = 16,
        REG_SIZE = 16;

    reg [REG_SIZE-1:0] ram [0:NUM_REG-1];
    integer i;

    // Sync read and write
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < NUM_REG; i = i + 1) begin
                ram[i] <= 16'h0000;
            end

            read_data0 <= 0;
            read_data1 <= 0;
        end else if (write_enable) begin
            ram[write_addr] <= write_data;
        end

        if (read_enable) begin
            read_data0 <= ram[read_addr0];
            read_data1 <= ram[read_addr1];
        end
    end
endmodule
