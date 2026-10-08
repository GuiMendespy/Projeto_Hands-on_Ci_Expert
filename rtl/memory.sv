`timescale 1ns/1ps

module memoria (
  input  logic        clk,
  input  logic        rst,       // Garantir que a porta de reset está conectada
  input  logic [1:0]  sel_item,
  input  logic        mem_read,
  input  logic        mem_write,
  output logic [7:0]  price,
  output logic [7:0]  stock
);

  // Importação do pacote dentro do escopo local do módulo
  import vending_pkg::*;

  // Matriz de memória: 4 posições, cada uma com 16 bits [Preço(15:8), Estoque(7:0)]
  logic [15:0] mem [0:3];

  // ------------------------------------------------------------------
  // LEITURA COMBINACIONAL
  // ------------------------------------------------------------------
  always_comb begin
    if (mem_read) begin
      price = mem[sel_item][15:8];
      stock = mem[sel_item][7:0];
    end else begin
      price = 8'd0;
      stock = 8'd0;
    end
  end

  // ------------------------------------------------------------------
  // ESCRITA E INICIALIZAÇÃO SÍNCRONA (Único bloco procedural que guia 'mem')
  // ------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst) begin
      // Inicialização segura e tratada como Reset síncrono
      mem[2'b00] <= {8'd25,  8'd5};  // Item 00 (Café):  Preço=25,  Estoque=5
      mem[2'b01] <= {8'd50,  8'd5};  // Item 01 (Suco):  Preço=50,  Estoque=5
      mem[2'b10] <= {8'd75,  8'd5};  // Item 10 (Refri): Preço=75,  Estoque=5
      mem[2'b11] <= {8'd100, 8'd5};  // Item 11 (Snack): Preço=100, Estoque=5
    end else if (mem_write && (mem[sel_item][7:0] > 8'd0)) begin
      // Decrementa o estoque quando ocorre uma venda bem-sucedida
      mem[sel_item][7:0] <= mem[sel_item][7:0] - 8'd1;
    end
  end

endmodule