`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;
import vending_tb_pkg::*;

module tb_vending;

  logic clk;
  logic rst;

  vending_interface vif (.clk(clk), .rst(rst));

  vending_top dut (
    .coin_in(vif.coin_in),
    .sel_item(vif.sel_item),
    .confirm(vif.confirm),
    .cancel(vif.cancel),
    .clk(clk),
    .rst(rst),
    .dispense(vif.dispense),
    .change_out(vif.change_out),
    .error(vif.error),
    .display(vif.display),
    .state_out(vif.state_out)
  );

  always #5 clk = ~clk;

  initial begin
    clk = 0;
    rst = 1;
    repeat (2) @(posedge clk);
    rst = 0;
  end

  initial begin
    uvm_config_db#(virtual vending_interface)::set(null, "*", "vif", vif);
    run_test("vending_test_compra_sucesso");
  end

endmodule : tb_vending