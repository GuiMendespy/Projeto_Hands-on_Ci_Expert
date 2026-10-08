import vending_pkg::*;

module subtrator (
  input  logic [7:0] credit,
  input  logic [7:0] price,
  output logic [7:0] change 
);

  assign change = credit - price;

endmodule