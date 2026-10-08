import vending_pkg::*;

module vending_top (
  input  logic [1:0] coin_in,
  input  logic [1:0] sel_item,
  input  logic       confirm,
  input  logic       cancel,
  input  logic       clk,
  input  logic       rst,
  output logic       dispense,
  output logic [7:0] change_out,
  output logic       error,
  output logic [7:0] display,
  output logic [2:0] state_out
);

  // Sinais internos de interconexão
  logic [7:0] w_credit;
  logic [7:0] w_price;
  logic [7:0] w_stock;
  logic [7:0] w_change;
  logic       w_can_sell;
  logic       w_credit_load;
  logic       w_reset_credit;
  logic       w_mem_read;
  logic       w_mem_write;
  estado_t    w_estado;

  // Saídas contínuas
  assign display   = w_credit; // Exibe crédito atual
  assign state_out = logic'(w_estado); // Converte enum para bits para o testbench

  // Instanciação da Unidade de Controle Simplificada
  unidade_controle fsm_inst (
    .clk(clk), .rst(rst), .cancel(cancel), .coin_in(coin_in), .confirm(confirm),
    .can_sell(w_can_sell), .estado(w_estado),
    .credit_load(w_credit_load), .reset_credit(w_reset_credit), .mem_read(w_mem_read), .mem_write(w_mem_write),
    .dispense(dispense), .error(error)
  );

  // Instanciação do Acumulador de Crédito (Passando w_estado no lugar de current_state)
  registrador_credito credit_inst (
    .clk(clk), .rst(rst), .cancel(cancel), .credit_load(w_credit_load), .reset_credit(w_reset_credit),
    .coin_in(coin_in), .credit(w_credit)
  );

  memoria mem_inst (
    .clk(clk), .rst(rst), .sel_item(sel_item), .mem_read(w_mem_read), .mem_write(w_mem_write),
    .price(w_price), .stock(w_stock)
  );

  comparador comp_inst (
    .credit(w_credit), .price(w_price), .stock(w_stock), .can_sell(w_can_sell)
  );

  subtrator sub_inst (
    .credit(w_credit), .price(w_price), .change(w_change)
  );

  // Saída registrada de Troco (Válido estritamente em CHANGE)
  always_ff @(posedge clk) begin
    if (rst || cancel) begin
      change_out <= 8'd0;
    end else if (w_estado == CHANGE) begin
      change_out <= w_change; // Registra o troco calculado
    end
  end

endmodule