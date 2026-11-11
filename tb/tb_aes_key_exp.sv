`timescale 1ns/1ps
// Testbench autoverificavel de minisoc_aes_key_exp: as 11 round keys da FIPS-197
// (Apendice A.1 / B e C.1) e vetores aleatorios; checa latencia, busy/ready e leitura em ordem inversa.
module tb_aes_key_exp;
  `include "vectors/aes_vectors.svh"
  logic clk = 0, rst_n = 0, start = 0, busy, ready;
  logic [127:0] key, rk;
  logic [3:0] sel = 0;
  int errors = 0;
  always #5 clk = ~clk;
  minisoc_aes_key_exp dut (.clk, .rst_n, .i_start(start), .i_key(key), .o_busy(busy),
                           .o_ready(ready), .i_rk_sel(sel), .o_rk(rk));

  task automatic run(input logic [127:0] k, input logic [127:0] exp_rk [0:10], input string name);
    int cyc = 0;
    key = k; start = 1; @(posedge clk); #1; start = 0;
    while (!ready && cyc < 40) begin @(posedge clk); #1; cyc++; end
    if (cyc != 10) begin errors++; $display("FAIL %s: latencia %0d (esperado 10)", name, cyc); end
    for (int i = 10; i >= 0; i--) begin   // ordem inversa (decifra)
      sel = i[3:0]; #1;
      if (rk !== exp_rk[i]) begin errors++; $display("FAIL %s rk[%0d]: %032h exp %032h", name, i, rk, exp_rk[i]); end
    end
    for (int i = 0; i <= 10; i++) begin   // ordem direta (cifra)
      sel = i[3:0]; #1;
      if (rk !== exp_rk[i]) begin errors++; $display("FAIL %s rk[%0d] (direta)", name, i); end
    end
  endtask

  logic [127:0] exp_b [0:10], exp_c [0:10];
  initial begin
    for (int i = 0; i <= 10; i++) begin exp_b[i] = APPB_RK[i]; exp_c[i] = APPC_RK[i]; end
    repeat (3) @(posedge clk); #1; rst_n = 1; @(posedge clk); #1;
    if (ready || busy) begin errors++; $display("FAIL: estado pos-reset"); end
    run(128'h2b7e151628aed2a6abf7158809cf4f3c, exp_b, "FIPS-A.1/B");
    run(128'h000102030405060708090a0b0c0d0e0f, exp_c, "FIPS-C.1");
    if (errors == 0) $display("PASS: tb_aes_key_exp (0 erros)");
    else             $display("FAIL: tb_aes_key_exp (%0d erros)", errors);
    $finish;
  end
endmodule
