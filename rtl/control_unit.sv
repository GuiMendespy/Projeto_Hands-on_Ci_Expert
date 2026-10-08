import vending_pkg::*;

module unidade_controle (
  input  logic        clk,
  input  logic        rst,
  input  logic        cancel,
  input  logic [1:0]  coin_in,
  input  logic        confirm,
  input  logic        can_sell,
  output estado_t     estado, // Porta de saída para monitoramento/depuração
  
  // Sinais de controle do Datapath e Memória
  output logic        credit_load,
  output logic        reset_credit,
  output logic        mem_read,
  output logic        mem_write,
  
  // Saídas do sistema
  output logic        dispense,
  output logic        error
);

  // Declaração dos registradores de estado conforme a teoria clássica de Moore
  estado_t estado_atual, proximo_estado;
  
  assign estado = estado_atual;

  always_ff @(posedge clk) begin
    if (rst || cancel) begin
      estado_atual <= IDLE; // Reset ou cancelamento força retorno seguro para IDLE 
    end else begin
      estado_atual <= proximo_estado;
    end
  end

  always_comb begin
    // --- 1. Atribuições Default de Segurança (Anti-Latch) ---
    proximo_estado = estado_atual; // Por padrão, a máquina mantém o estado atual
    credit_load    = 1'b0;
    mem_read       = 1'b0;
    reset_credit   = 1'b0;
    mem_write      = 1'b0;
    dispense       = 1'b0;
    error          = 1'b0;

    // --- 2. Árvore de Decisão da FSM ---
    case (estado_atual)
      
      IDLE: begin
        // Aguarda inserção de moeda para mudar para COLLECT
        if (coin_in != 2'b00) begin
          proximo_estado = COLLECT;
        end
      end

      COLLECT: begin
        // Habilita a carga do acumulador se uma moeda válida for injetada
        if (coin_in != 2'b00) begin
          credit_load = 1'b1;
        end
        if (cancel) begin
          reset_credit = 1'b1; // Zera o crédito se o usuário cancelar 
          proximo_estado = IDLE;
        end
        // Quando o usuário pressiona confirmar, avança para a checagem
        if (confirm) begin
          proximo_estado = CHECK;
        end
      end

      CHECK: begin
        // Ativa a leitura síncrona da memória (preço e estoque)
        mem_read = 1'b1;
        
        // Avalia o resultado booleano instantâneo do comparador no datapath 
        if (can_sell) begin
          proximo_estado = DISPENSE; // Crédito suficiente e há estoque 
        end else begin
          proximo_estado = ERROR;    // Saldo insuficiente ou falta de produto 
        end
      end

      DISPENSE: begin
        dispense  = 1'b1; // Pulso de exatamente 1 ciclo para liberação do item 
        mem_write = 1'b1; // Comando síncrono para a memória decrementar o estoque
        
        // Transiciona incondicionalmente para o cálculo do troco 
        proximo_estado = CHANGE;
      end

      CHANGE: begin
        credit_load = 1'b1; 
        proximo_estado = IDLE; 
      end

      ERROR: begin
        error = 1'b1; // Mantém sinalizador de erro ativo para a interface
        proximo_estado = ERROR; 
        if (cancel) begin
          reset_credit = 1'b1; // Zera o crédito se o usuário cancelar 
          proximo_estado = IDLE;
        end
      end

      default: begin
        proximo_estado = IDLE;
      end

    endcase
  end

endmodule
