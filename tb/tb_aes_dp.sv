`timescale 1ns/1ps
// Testbench autoverificavel de minisoc_aes_key_exp (via dp) e minisoc_aes_dp.
//  - vetores FIPS-197 Apendice C.1 e B, nos dois sentidos
//  - 64 vetores aleatorios (modelo Python, validado contra a biblioteca 'cryptography')
//  - latencia, o_done pulsado, o_block mantido, start ignorado com chave invalida
module tb_aes_dp;
  `include "vectors/aes_vectors.svh"

  logic clk = 0, rst_n = 0;
  logic [127:0] key, block_in, block_out;
  logic key_load = 0, key_ready, start = 0, decrypt = 0, busy, done;
  int errors = 0;

  always #5 clk = ~clk;

  minisoc_aes_dp dut (
    .clk, .rst_n, .i_key(key), .i_key_load(key_load), .o_key_ready(key_ready),
    .i_start(start), .i_decrypt(decrypt), .i_block(block_in), .o_block(block_out),
    .o_busy(busy), .o_done(done)
  );

  task automatic load_key(input logic [127:0] k);
    int t;
    key = k; key_load = 1; @(posedge clk); #1; key_load = 0;
    t = 0;
    while (!key_ready && t < 100) begin @(posedge clk); #1; t++; end
    if (!key_ready) begin errors++; $display("FAIL: timeout key_ready"); end
    @(posedge clk); #1;
  endtask

  task automatic run_block(input logic [127:0] din, input logic dec, output logic [127:0] dout, output int cycles);
    block_in = din; decrypt = dec; start = 1; cycles = 0;
    @(posedge clk); #1; start = 0;
    while (!done && cycles < 50) begin @(posedge clk); #1; cycles++; end
    dout = block_out;
    if (cycles >= 50) begin errors++; $display("FAIL: timeout done"); end
  endtask

  task automatic expect_blk(input string what, input logic [127:0] got, input logic [127:0] exp);
    if (got !== exp) begin errors++; $display("FAIL %s: got=%032h exp=%032h", what, got, exp); end
  endtask

  logic [127:0] r; int cyc;

  initial begin
    repeat (3) @(posedge clk); #1; rst_n = 1; @(posedge clk); #1;

    // start sem chave valida deve ser ignorado
    block_in = 128'h0; start = 1; @(posedge clk); #1; start = 0; repeat (3) @(posedge clk);
    if (busy || done) begin errors++; $display("FAIL: start aceito sem chave"); end

    $display("== FIPS-197 Apendice C.1");
    load_key(128'h000102030405060708090a0b0c0d0e0f);
    run_block(128'h00112233445566778899aabbccddeeff, 0, r, cyc);
    expect_blk("C.1 encrypt", r, 128'h69c4e0d86a7b0430d8cdb78070b4c55a);
    $display("   latencia cifra = %0d ciclos", cyc);
    run_block(128'h69c4e0d86a7b0430d8cdb78070b4c55a, 1, r, cyc);
    expect_blk("C.1 decrypt", r, 128'h00112233445566778899aabbccddeeff);
    $display("   latencia decifra = %0d ciclos", cyc);

    $display("== FIPS-197 Apendice B");
    load_key(128'h2b7e151628aed2a6abf7158809cf4f3c);
    run_block(128'h3243f6a8885a308d313198a2e0370734, 0, r, cyc);
    expect_blk("B encrypt", r, 128'h3925841d02dc09fbdc118597196a0b32);
    run_block(128'h3925841d02dc09fbdc118597196a0b32, 1, r, cyc);
    expect_blk("B decrypt", r, 128'h3243f6a8885a308d313198a2e0370734);
    repeat (4) @(posedge clk);
    expect_blk("o_block mantido apos done", block_out, 128'h3243f6a8885a308d313198a2e0370734);

    $display("== %0d vetores aleatorios (cifra e decifra)", N_RND);
    for (int i = 0; i < N_RND; i++) begin
      load_key(RND_KEY[i]);
      run_block(RND_PT[i], 0, r, cyc); expect_blk($sformatf("rnd[%0d] enc", i), r, RND_CT[i]);
      run_block(RND_CT[i], 1, r, cyc); expect_blk($sformatf("rnd[%0d] dec", i), r, RND_PT[i]);
    end

    if (errors == 0) $display("PASS: tb_aes_dp (0 erros)");
    else             $display("FAIL: tb_aes_dp (%0d erros)", errors);
    $finish;
  end
endmodule
