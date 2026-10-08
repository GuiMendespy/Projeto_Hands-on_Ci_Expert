`timescale 1ns/1ps
import vending_pkg::*;

module registrador_credito (
  input  logic        clk,
  input  logic        rst,
  input  logic        cancel,
  input  logic        credit_load,
  input  logic [1:0]  coin_in,
  input  logic        reset_credit,
  output logic [7:0]  credit
);

  logic [7:0] coin_value;

  // Mapeamento combinacional das moedas (Sintetizável)
  always_comb begin
    case (coin_in)
      2'b01  : coin_value = VAL_MOEDA_25;
      2'b10  : coin_value = VAL_MOEDA_50;
      2'b11  : coin_value = VAL_MOEDA_100;
      default: coin_value = 8'd0;
    endcase
  end

  // Registrador síncrono de acúmulo puro
  // Removido o '$isunknown' que causava o crash fatal no Design Compiler
  always_ff @(posedge clk) begin
    if (rst || reset_credit || cancel) begin
      credit <= 8'd0; 
    end else if (credit_load) begin
      credit <= credit + coin_value; // Acúmulo direto em lógica binária pura
    end
  end

endmodule