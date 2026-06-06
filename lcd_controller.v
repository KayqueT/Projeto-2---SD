module lcd_controller (
    input  wire        clk,
    input  wire        reset,
    input  wire        iniciar,
    input  wire [2:0]  opcode,
    input  wire [3:0]  registrador_destino,
    input  wire [15:0] valor_resultado,

    output reg  [7:0]  lcd_dados,
    output reg         lcd_rs,
    output reg         lcd_rw,
    output reg         lcd_en
);

    localparam ESPERA_MS = 50_000;

    localparam [3:0]
        EST_OCIOSO        = 4'd0,
        EST_ESPERA_CPU    = 4'd1,
        EST_INIT_1        = 4'd2,
        EST_INIT_2        = 4'd3,
        EST_INIT_3        = 4'd4,
        EST_INIT_4        = 4'd5,
        EST_LINHA1_POS    = 4'd6,
        EST_ESCREVE_L1    = 4'd7,
        EST_LINHA2_POS    = 4'd8,
        EST_ESCREVE_L2    = 4'd9,
        EST_DESLIGADO     = 4'd10;

    localparam OP_LOAD    = 3'b000;
    localparam OP_ADD     = 3'b001;
    localparam OP_ADDI    = 3'b010;
    localparam OP_SUB     = 3'b011;
    localparam OP_SUBI    = 3'b100;
    localparam OP_MUL     = 3'b101;
    localparam OP_CLEAR   = 3'b110;
    localparam OP_DISPLAY = 3'b111;

    reg [3:0]  estado_atual, proximo_estado;
    reg [16:0] cnt_espera;
    reg [3:0]  reg_indice;

    reg [7:0] linha1 [0:15];
    reg [7:0] linha2 [0:15];
    integer k;

    function [7:0] digito_ascii;
        input [3:0] digito;
        begin
            digito_ascii = 8'h30 + {4'b0, digito};
        end
    endfunction

    reg [15:0] valor_abs;
    reg        valor_negativo;
    reg [19:0] bcd;
    integer i;

    always @(*) begin
        valor_negativo = valor_resultado[15];
        valor_abs      = valor_negativo ? (~valor_resultado + 1'b1) : valor_resultado;
        bcd            = 20'd0;

        for (i = 15; i >= 0; i = i - 1) begin
            if (bcd[3:0] >= 5)   bcd[3:0]   = bcd[3:0] + 3;
            if (bcd[7:4] >= 5)   bcd[7:4]   = bcd[7:4] + 3;
            if (bcd[11:8] >= 5)  bcd[11:8]  = bcd[11:8] + 3;
            if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
            if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
            bcd = {bcd[18:0], valor_abs[i]};
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (k = 0; k < 16; k = k + 1) begin
                linha1[k] <= 8'h20;
                linha2[k] <= 8'h20;
            end
        end
        else if (estado_atual == EST_ESPERA_CPU && cnt_espera == 10) begin
            linha2[0] <= valor_negativo ? 8'h2D : 8'h2B;
            linha2[1] <= digito_ascii(bcd[19:16]);
            linha2[2] <= digito_ascii(bcd[15:12]);
            linha2[3] <= digito_ascii(bcd[11:8]);
            linha2[4] <= digito_ascii(bcd[7:4]);
            linha2[5] <= digito_ascii(bcd[3:0]);
            for (k = 6; k < 16; k = k + 1) linha2[k] <= 8'h20;

            case (opcode)
                OP_ADD: begin
                    linha1[0]<=8'h41; linha1[1]<=8'h44; linha1[2]<=8'h44; linha1[3]<=8'h20;
                end
                OP_ADDI: begin
                    linha1[0]<=8'h41; linha1[1]<=8'h44; linha1[2]<=8'h44; linha1[3]<=8'h49;
                end
                OP_SUB: begin
                    linha1[0]<=8'h53; linha1[1]<=8'h55; linha1[2]<=8'h42; linha1[3]<=8'h20;
                end
                OP_SUBI: begin
                    linha1[0]<=8'h53; linha1[1]<=8'h55; linha1[2]<=8'h42; linha1[3]<=8'h49;
                end
                OP_MUL: begin
                    linha1[0]<=8'h4D; linha1[1]<=8'h55; linha1[2]<=8'h4C; linha1[3]<=8'h20;
                end
                OP_LOAD: begin
                    linha1[0]<=8'h4C; linha1[1]<=8'h4F; linha1[2]<=8'h41; linha1[3]<=8'h44;
                end
                OP_CLEAR: begin
                    linha1[0]<=8'h43; linha1[1]<=8'h4C; linha1[2]<=8'h52; linha1[3]<=8'h20;
                end
                OP_DISPLAY: begin
                    linha1[0]<=8'h44; linha1[1]<=8'h50; linha1[2]<=8'h4C; linha1[3]<=8'h20;
                end
                default: begin
                    linha1[0]<=8'h3F; linha1[1]<=8'h3F; linha1[2]<=8'h3F; linha1[3]<=8'h20;
                end
            endcase

            linha1[4] <= 8'h20; linha1[5] <= 8'h20;

            linha1[6]  <= 8'h5B;
            linha1[7]  <= registrador_destino[3] ? 8'h31 : 8'h30;
            linha1[8]  <= registrador_destino[2] ? 8'h31 : 8'h30;
            linha1[9]  <= registrador_destino[1] ? 8'h31 : 8'h30;
            linha1[10] <= registrador_destino[0] ? 8'h31 : 8'h30;
            linha1[11] <= 8'h5D;
            for (k = 12; k < 16; k = k + 1) linha1[k] <= 8'h20;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) estado_atual <= EST_INIT_1;
        else estado_atual <= proximo_estado;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) cnt_espera <= 0;
        else if (estado_atual != proximo_estado) cnt_espera <= 0;
        else cnt_espera <= cnt_espera + 1;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) reg_indice <= 4'd0;
        else if (estado_atual == EST_LINHA1_POS || estado_atual == EST_LINHA2_POS)
            reg_indice <= 4'd0;
        else if ((estado_atual == EST_ESCREVE_L1 || estado_atual == EST_ESCREVE_L2) && cnt_espera >= ESPERA_MS)
            reg_indice <= reg_indice + 1'b1;
    end

    always @(*) begin
        proximo_estado = estado_atual;
        lcd_rs     = 1'b0;
        lcd_rw     = 1'b0;
        lcd_en     = 1'b0;
        lcd_dados  = 8'h00;

        case (estado_atual)
            EST_INIT_1: begin
                lcd_dados = 8'b0011_1000;
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                if (cnt_espera >= ESPERA_MS) proximo_estado = EST_INIT_2;
            end
            EST_INIT_2: begin
                lcd_dados = 8'b0000_1100;
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                if (cnt_espera >= ESPERA_MS) proximo_estado = EST_INIT_3;
            end
            EST_INIT_3: begin
                lcd_dados = 8'b0000_0110;
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                if (cnt_espera >= ESPERA_MS) proximo_estado = EST_INIT_4;
            end
            EST_INIT_4: begin
                lcd_dados = 8'b0000_0001;
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                if (cnt_espera >= ESPERA_MS) proximo_estado = EST_OCIOSO;
            end
            EST_OCIOSO: begin
                if (iniciar) proximo_estado = EST_ESPERA_CPU;
            end
            EST_ESPERA_CPU: begin
                if (cnt_espera >= 20) proximo_estado = EST_LINHA1_POS;
            end
            EST_LINHA1_POS: begin
                lcd_dados = 8'h80;
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                if (cnt_espera >= ESPERA_MS) proximo_estado = EST_ESCREVE_L1;
            end
            EST_ESCREVE_L1: begin
                lcd_rs    = 1'b1;
                lcd_dados = linha1[reg_indice];
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                if (cnt_espera >= ESPERA_MS && reg_indice == 4'd15) proximo_estado = EST_LINHA2_POS;
            end
            EST_LINHA2_POS: begin
                lcd_dados = 8'hC0;
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                if (cnt_espera >= ESPERA_MS) proximo_estado = EST_ESCREVE_L2;
            end
            EST_ESCREVE_L2: begin
                lcd_rs    = 1'b1;
                lcd_dados = linha2[reg_indice];
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                if (cnt_espera >= ESPERA_MS && reg_indice == 4'd15) proximo_estado = EST_OCIOSO;
            end
            EST_DESLIGADO: begin
                lcd_dados  = 8'b0000_0001;
                lcd_en     = (cnt_espera < 5) ? 1'b1 : 1'b0;
            end
            default: proximo_estado = EST_OCIOSO;
        endcase
    end
endmodule