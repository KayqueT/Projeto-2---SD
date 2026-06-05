`timescale 1ns/1ps
// Inicializa o display e escreve a operação + resultado.
// Barramento de dados 8 bits + RS, RW, EN.

module lcd_controlador (
    input  wire        clk,           // Clock da placa (50 MHz)
    input  wire        reset,         // Reset assíncrono
    input  wire        iniciar,       // Pulso para iniciar nova escrita
    input  wire [2:0]  opcode,        // Opcode da instrução executada
    input  wire [3:0]  registrador_destino, // Número do reg de destino (0–15)
    input  wire [15:0] valor_resultado,     // Valor a exibir (com sinal)

    output reg  [7:0]  lcd_dados,     // Barramento de dados D7–D0
    output reg         lcd_rs,        // Register Select: 0=cmd, 1=dado
    output reg         lcd_rw,        // Read/Write: sempre 0 (escrita)
    output reg         lcd_en,        // Enable (negedge dispara LCD)
    output reg         lcd_ligado     // Indica se o display está ativo
);

    // Parâmetro de temporização
    // Clock 50 MHz → 1 ciclo = 20 ns
    // 1 ms = 50 000 ciclos (espera recomendada após ENABLE)
    localparam ESPERA_MS = 50_000;

    // Estados da máquina de estados do controlador
	 
    localparam [3:0]
        EST_OCIOSO        = 4'd0,   // Aguarda comando
        EST_INIT_1        = 4'd1,   // Comando: Function Set
        EST_INIT_2        = 4'd2,   // Comando: Display ON
        EST_INIT_3        = 4'd3,   // Comando: Entry Mode
        EST_INIT_4        = 4'd4,   // Comando: Clear Display
        EST_LINHA1_POS    = 4'd5,   // Posiciona cursor linha 1
        EST_ESCREVE_L1    = 4'd6,   // Escreve caracteres linha 1
        EST_LINHA2_POS    = 4'd7,   // Posiciona cursor linha 2
        EST_ESCREVE_L2    = 4'd8,   // Escreve caracteres linha 2
        EST_ESPERA        = 4'd9,   // Aguarda pulso de EN descer
        EST_DESLIGADO     = 4'd10;  // Display apagado (Clear + OFF)

    // Nomes das operações em ASCII (4 caracteres + espaço)
    // Cada instrução ocupa 8 bytes: 4 letras + 4 espaços
    localparam OP_LOAD    = 3'b000;
    localparam OP_ADD     = 3'b001;
    localparam OP_ADDI    = 3'b010;
    localparam OP_SUB     = 3'b011;
    localparam OP_SUBI    = 3'b100;
    localparam OP_MUL     = 3'b101;
    localparam OP_CLEAR   = 3'b110;
    localparam OP_DISPLAY = 3'b111;

    // Registradores internos
    reg [3:0]  estado_atual, proximo_estado;
    reg [16:0] contador_espera; // Contador de ciclos para 1 ms
    reg [3:0]  indice_char;     // Índice do caractere sendo escrito
    reg        en_interno;      // Controle interno do sinal EN

    // Linha 1 do LCD: Nome da operação + endereço do registrador
    // Linha 2 do LCD: Valor com sinal (+/-XXXXX)
    // Cada linha armazena até 16 caracteres ASCII
    reg [7:0] linha1 [0:15];
    reg [7:0] linha2 [0:15];

    integer k;

    // Função auxiliar: converte dígito (0–9) em ASCII
    function [7:0] digito_ascii;
        input [3:0] digito;
        begin
            digito_ascii = 8'h30 + {4'b0, digito}; // '0' = 0x30
        end
    endfunction

    // Conversão do valor resultado para BCD (5 dígitos decimais)
    // Utiliza o algoritmo Double Dabble simplificado
    reg [15:0] valor_abs;      // Módulo do valor
    reg        valor_negativo; // Flag de sinal
    reg [3:0]  bcd_milhar, bcd_centena, bcd_dezena, bcd_unidade, bcd_dez_milhar;

    always @(*) begin
        valor_negativo = valor_resultado[15]; // MSB = bit de sinal (complemento 2)
        valor_abs      = valor_negativo ? (~valor_resultado + 1'b1) : valor_resultado;

        // Decomposição decimal (limitado a 99999 para display)
        bcd_dez_milhar = (valor_abs / 10000) % 10;
        bcd_milhar     = (valor_abs / 1000)  % 10;
        bcd_centena    = (valor_abs / 100)   % 10;
        bcd_dezena     = (valor_abs / 10)    % 10;
        bcd_unidade    =  valor_abs          % 10;
    end

    // Montagem das linhas do LCD conforme o tipo de instrução
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (k = 0; k < 16; k = k + 1) begin
                linha1[k] <= 8'h20; // Espaço
                linha2[k] <= 8'h20;
            end
        end
        else if (iniciar) begin
            // Linha 2: sinal + 5 dígitos decimais
            linha2[0] <= valor_negativo ? 8'h2D : 8'h2B; // '-' ou '+'
            linha2[1] <= digito_ascii(bcd_dez_milhar);
            linha2[2] <= digito_ascii(bcd_milhar);
            linha2[3] <= digito_ascii(bcd_centena);
            linha2[4] <= digito_ascii(bcd_dezena);
            linha2[5] <= digito_ascii(bcd_unidade);
            linha2[6] <= 8'h20; linha2[7]  <= 8'h20;
            linha2[8] <= 8'h20; linha2[9]  <= 8'h20;
            linha2[10]<= 8'h20; linha2[11] <= 8'h20;
            linha2[12]<= 8'h20; linha2[13] <= 8'h20;
            linha2[14]<= 8'h20; linha2[15] <= 8'h20;

            // Linha 1: nome da operação (4 chars)
            case (opcode)
                OP_ADD: begin
                    linha1[0]<=8'h41; linha1[1]<=8'h44; // "AD"
                    linha1[2]<=8'h44; linha1[3]<=8'h20; // "D "
                end
                OP_ADDI: begin
                    linha1[0]<=8'h41; linha1[1]<=8'h44; // "AD"
                    linha1[2]<=8'h44; linha1[3]<=8'h49; // "DI"
                end
                OP_SUB: begin
                    linha1[0]<=8'h53; linha1[1]<=8'h55; // "SU"
                    linha1[2]<=8'h42; linha1[3]<=8'h20; // "B "
                end
                OP_SUBI: begin
                    linha1[0]<=8'h53; linha1[1]<=8'h55; // "SU"
                    linha1[2]<=8'h42; linha1[3]<=8'h49; // "BI"
                end
                OP_MUL: begin
                    linha1[0]<=8'h4D; linha1[1]<=8'h55; // "MU"
                    linha1[2]<=8'h4C; linha1[3]<=8'h20; // "L "
                end
                OP_LOAD: begin
                    linha1[0]<=8'h4C; linha1[1]<=8'h4F; // "LO"
                    linha1[2]<=8'h41; linha1[3]<=8'h44; // "AD"
                end
                OP_CLEAR: begin
                    linha1[0]<=8'h43; linha1[1]<=8'h4C; // "CL"
                    linha1[2]<=8'h52; linha1[3]<=8'h20; // "R "
                end
                OP_DISPLAY: begin
                    linha1[0]<=8'h44; linha1[1]<=8'h50; // "DP"
                    linha1[2]<=8'h4C; linha1[3]<=8'h20; // "L "
                end
                default: begin
                    linha1[0]<=8'h3F; linha1[1]<=8'h3F; // "??"
                    linha1[2]<=8'h3F; linha1[3]<=8'h20;
                end
            endcase

            // Caracteres 4–7: espaços de separação
            linha1[4] <= 8'h20; linha1[5] <= 8'h20;

            // Linha 1, posições 6–11: "[XXXX]" (endereço binário do registrador)
            // Exibe o número do registrador de destino em binário entre colchetes
            linha1[6]  <= 8'h5B; // '['
            linha1[7]  <= registrador_destino[3] ? 8'h31 : 8'h30; // bit 3
            linha1[8]  <= registrador_destino[2] ? 8'h31 : 8'h30; // bit 2
            linha1[9]  <= registrador_destino[1] ? 8'h31 : 8'h30; // bit 1
            linha1[10] <= registrador_destino[0] ? 8'h31 : 8'h30; // bit 0
            linha1[11] <= 8'h5D; // ']'
            linha1[12] <= 8'h20; linha1[13] <= 8'h20;
            linha1[14] <= 8'h20; linha1[15] <= 8'h20;
        end
    end

    // Máquina de estados — controla sequência de comandos ao LCD
    always @(posedge clk or posedge reset) begin
        if (reset)
            estado_atual <= EST_INIT_1;
        else
            estado_atual <= proximo_estado;
    end

    // Contador de espera (usado entre comandos)
    reg [16:0] cnt_espera;
    always @(posedge clk or posedge reset) begin
        if (reset)
            cnt_espera <= 0;
        else if (estado_atual != proximo_estado)
            cnt_espera <= 0;
        else
            cnt_espera <= cnt_espera + 1;
    end

    // Lógica de transição e saída
    always @(*) begin
        // Valores padrão
        proximo_estado = estado_atual;
        lcd_rs   = 1'b0;
        lcd_rw   = 1'b0;
        lcd_en   = 1'b0;
        lcd_dados= 8'h00;
        lcd_ligado = 1'b1;
        indice_char = 4'd0;

        case (estado_atual)

            // Inicialização: Function Set (DL=1, N=1, F=0 → 8 bits, 2 linhas, 5x8)
            EST_INIT_1: begin
                lcd_rs    = 1'b0;
                lcd_dados = 8'b0011_1000; // 0x38
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                if (cnt_espera >= ESPERA_MS) proximo_estado = EST_INIT_2;
            end

            // Display ON/OFF: D=1, C=0, B=0 (display ligado, sem cursor)
            EST_INIT_2: begin
                lcd_rs    = 1'b0;
                lcd_dados = 8'b0000_1100; // 0x0C
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                if (cnt_espera >= ESPERA_MS) proximo_estado = EST_INIT_3;
            end

            // Entry Mode: I/D=1, S=0 (cursor move para direita)
            EST_INIT_3: begin
                lcd_rs    = 1'b0;
                lcd_dados = 8'b0000_0110; // 0x06
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                if (cnt_espera >= ESPERA_MS) proximo_estado = EST_INIT_4;
            end

            // Limpar Display
            EST_INIT_4: begin
                lcd_rs    = 1'b0;
                lcd_dados = 8'b0000_0001; // 0x01
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                if (cnt_espera >= ESPERA_MS) proximo_estado = EST_OCIOSO;
            end

            // Ocioso: aguarda sinal "iniciar"
            EST_OCIOSO: begin
                lcd_ligado = 1'b1;
                if (iniciar) proximo_estado = EST_LINHA1_POS;
            end

            // Posiciona cursor no início da linha 1 (endereço 0x80)
            EST_LINHA1_POS: begin
                lcd_rs    = 1'b0;
                lcd_dados = 8'h80; // DDRAM addr linha 1
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                if (cnt_espera >= ESPERA_MS) proximo_estado = EST_ESCREVE_L1;
            end

            // Escreve os 16 caracteres da linha 1
            EST_ESCREVE_L1: begin
                lcd_rs    = 1'b1; // Modo de dado
                lcd_dados = linha1[indice_char];
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                if (cnt_espera >= ESPERA_MS) begin
                    if (indice_char == 4'd15)
                        proximo_estado = EST_LINHA2_POS;
                    // indice_char é incrementado no bloco síncrono abaixo
                end
            end

            // Posiciona cursor no início da linha 2 (endereço 0xC0)
            EST_LINHA2_POS: begin
                lcd_rs    = 1'b0;
                lcd_dados = 8'hC0; // DDRAM addr linha 2
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                if (cnt_espera >= ESPERA_MS) proximo_estado = EST_ESCREVE_L2;
            end

            // Escreve os 16 caracteres da linha 2
            EST_ESCREVE_L2: begin
                lcd_rs    = 1'b1;
                lcd_dados = linha2[indice_char];
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                if (cnt_espera >= ESPERA_MS) begin
                    if (indice_char == 4'd15)
                        proximo_estado = EST_OCIOSO;
                end
            end

            // Display desligado (reset do sistema)
            EST_DESLIGADO: begin
                lcd_rs    = 1'b0;
                lcd_dados = 8'b0000_0001; // Limpa display
                lcd_en    = (cnt_espera < 5) ? 1'b1 : 1'b0;
                lcd_ligado = 1'b0;
            end

            default: proximo_estado = EST_OCIOSO;

        endcase
    end

    // Controle do índice de caractere (incrementa a cada ciclo completo de escrita de um caractere)
    reg [3:0] reg_indice;
    always @(posedge clk or posedge reset) begin
        if (reset)
            reg_indice <= 4'd0;
        else if (estado_atual == EST_LINHA1_POS || estado_atual == EST_LINHA2_POS)
            reg_indice <= 4'd0; // Reinicia índice ao posicionar cursor
        else if ((estado_atual == EST_ESCREVE_L1 || estado_atual == EST_ESCREVE_L2)
                  && cnt_espera >= ESPERA_MS && reg_indice < 4'd15)
            reg_indice <= reg_indice + 1'b1;
    end
endmodule
