# Mini‑CPU
### Projeto 2 – SD | CIn UFPE | 2026.1

## Visão Geral da Arquitetura

```
          ┌─────────────────────────────────────────┐
          │           module_mini_cpu.v             │
          │  (Top‑Level — máquina de estados CPU)   │
          │                                         │
          │  ┌───────────┐      ┌─────────────────┐ │
Switches ─┼─►│  Decodif. │─────►│  module_alu.v   │ │
Botões   ─┼─►│  (CPU)    │      │  (ULA)          │ │
          │  └───────────┘      └────────┬────────┘ │
          │        │                     │resultado │
          │        │            ┌────────▼────────┐ │
          │        └───────────►│   memory.v      │ │
          │                     │  (RAM 16×16 b.) │ │
          │                     └────────┬────────┘ │
          │                              │leitura   │
          │                     ┌────────▼────────┐ │
          │                     │ lcd_controlador │ │
          │                     │    .v (LCD)     │ │
          └─────────────────────└────────┬────────┘─┘
                                         │
                                    LCD 16×2
```

## Módulos do Projeto

### 1. `memory.v` — Memória RAM 16 × 16 bits

**O que faz:** armazena os 16 registradores (R0–R15), cada um com 16 bits.

| Sinal | Direção | Descrição |
|---|---|---|
| `clk` | Entrada | Clock 50 MHz |
| `reset` | Entrada | Zera todos os registradores |
| `escrever` | Entrada | Habilita escrita (1 = escreve) |
| `endereco[3:0]` | Entrada | Registrador acessado (0–15) |
| `dado_entrada[15:0]` | Entrada | Valor a gravar |
| `dado_saida[15:0]` | Saída | Valor lido (combinacional) |

**Como funciona:**
- A **escrita** é **síncrona**: só acontece na borda de subida do clock quando `escrever=1`
- A **leitura** é **combinacional**: o dado aparece imediatamente ao mudar o endereço
- O `reset` é **assíncrono**: zera tudo instantaneamente, independente do clock

---

### 2. `module_alu.v` — Unidade Lógica e Aritmética (ULA)

**O que faz:** recebe dois operandos e um opcode, retorna o resultado da operação.

| Opcode | Instrução | Operação |
|---|---|---|
| `000` | LOAD | `resultado = Imm` |
| `001` | ADD | `resultado = Op1 + Op2` |
| `010` | ADDI | `resultado = Op1 + Imm` |
| `011` | SUB | `resultado = Op1 - Op2` |
| `100` | SUBI | `resultado = Op1 - Imm` |
| `101` | MUL | `resultado = Op1 × Imm` |
| `110` | CLEAR | Sem cálculo (tratado na CPU) |
| `111` | DISPLAY | Passa Op1 direto |

**Imediato com sinal:** o bit `sinal_imediato` determina se o valor de 6 bits
é positivo ou negativo. Ex.: `sinal=1, imm=000111` → valor = **−7**.

A ULA é **puramente combinacional** (sem clock) — o resultado aparece
instantaneamente após mudar as entradas.

---

### 3. `lcd_controlador.v` — Controlador do LCD HD44780

**O que faz:** inicializa o display e escreve a operação + resultado nas 2 linhas.

**Sequência de inicialização (automática ao ligar):**
```
Function Set (0x38) → Display ON (0x0C) → Entry Mode (0x06) → Clear (0x01)
```

**Layout do LCD após cada instrução:**

```
┌────────────────┐
│ OP   [DDDD]    │  ← Linha 1: nome + registrador destino em binário
│ ±NNNNN         │  ← Linha 2: sinal + valor decimal (5 dígitos)
└────────────────┘
```

Exemplo após `ADD R1, R0, R2` com resultado 22:
```
┌────────────────┐
│ ADD  [0001]    │
│ +00022         │
└────────────────┘
```

---
### 4. `module_mini_cpu.v` — CPU Principal (Top‑Level)

**O que faz:** integra todos os módulos e implementa o ciclo
**Fetch → Decode → Execute → Write → Display**.

#### Estados da máquina de estados:

```
DESLIGADO ──[LIGAR solto]──► OCIOSO
   ▲                            │
   └──────[LIGAR solto]─────────┘   (desliga)
                                │
                         [ENVIAR solto]
                                │
                                ▼
                             BUSCA
                          (captura switches)
                                │
                                ▼
                          DECODIFICA
                       (separa campos da instr.)
                                │
                                ▼
                            EXECUTA
                        (lê memória / aciona ULA)
                                │
                                ▼
                            ESCRITA
                         (grava na memória)
                                │
                                ▼
                            EXIBE ──► OCIOSO
                         (atualiza LCD)
```
