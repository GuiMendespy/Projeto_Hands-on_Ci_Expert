import vending_pkg::*;

module comparador (
  input  logic [7:0] credit, // Crédito acumulado
  input  logic [7:0] price,  // Preço vindo da memória
  input  logic [7:0] stock,  // Estoque vindo da memória
  output logic       can_sell // Sinal combinacional resultante
);

  assign can_sell = (credit >= price) && (stock > 8'b0);

endmodule