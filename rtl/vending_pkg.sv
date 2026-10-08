`timescale 1ns/1ps
package vending_pkg;

  // Codificação de 3 bits para os 6 estados da FSM (Moore)
  typedef enum logic [2:0] {
    IDLE     = 3'b000,
    COLLECT  = 3'b001,
    CHECK    = 3'b010,
    DISPENSE = 3'b011,
    CHANGE   = 3'b100,
    ERROR    = 3'b101
  } estado_t;

  // Constantes em ponto fixo (valores em centavos) para o memória e o comparador.
  // Antes: parameter VAL_MOEDA_25 = 25;
  parameter bit [7:0] VAL_MOEDA_25 = 8'd25;
  parameter bit [7:0] VAL_MOEDA_50 = 8'd50;
  parameter bit [7:0] VAL_MOEDA_100 = 8'd100;

endpackage : vending_pkg