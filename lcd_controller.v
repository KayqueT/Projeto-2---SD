module lcd_controller (
    // CPU Interface
    input  wire        clk,
    input  wire        rst,
    input  wire        update_trigger, // Pulse from CPU to start drawing
    input  wire [2:0]  opcode,         // Current instruction
    input  wire [3:0]  dst,            // Destination register
    input  wire [15:0] data,           // Data result from operations

    output wire [7:0]  lcd_data,       
    output wire        lcd_rs,        
    output wire        lcd_rw,         
    output wire        lcd_en,         
    output wire        lcd_on,         
    output wire        lcd_blon
);

    wire [7:0] char_data;
    wire       char_valid;
    wire       next_char_req;

    // Module 1: Formatter
    // Converts binary/hex data into 32 formatted ASCII characters
    lcd_formatter formatter (
        .clk            (clk),
        .rst            (rst),
        .update_trigger (update_trigger),
        .opcode         (opcode),
        .dst            (dst),
        .data           (data),
        .next_char_req  (next_char_req),
        
        .char_data      (char_data),
        .char_valid     (char_valid)
    );

    // Physical Driver
    // Handles initialization, timings, and pin toggling
    lcd_driver driver (
        .clk            (clk),
        .rst            (rst),
        .char_data      (char_data),
        .char_valid     (char_valid),
        
        .lcd_data       (lcd_data),
        .lcd_rs         (lcd_rs),
        .lcd_rw         (lcd_rw),
        .lcd_en         (lcd_en),
        .lcd_on         (lcd_on),
        .lcd_blon       (lcd_blon),
        .next_char_req  (next_char_req)  // Request next char from formatter
    );

endmodule