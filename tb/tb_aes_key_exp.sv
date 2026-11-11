`timescale 1ns/1ps

// Testbench autoverificavel de minisoc_aes_key_exp com logs detalhados no terminal
module tb_aes_key_exp;
  `include "vectors/aes_vectors.svh"

  // -------------------------------------------------------------------------
  // Sinais de Interface
  // -------------------------------------------------------------------------
  logic clk = 0, rst_n = 0, start = 0, busy, ready;
  logic [127:0] key, rk;
  logic [3:0] sel = 0;

  // Contadores globais de teste
  int total_tests  = 0;
  int passed_tests = 0;
  int failed_tests = 0;

  always #5 clk = ~clk;

  // Instanciação do DUT
  minisoc_aes_key_exp dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .i_start  (start),
    .i_key    (key),
    .o_busy   (busy),
    .o_ready  (ready),
    .i_rk_sel (sel),
    .o_rk     (rk)
  );

  // -------------------------------------------------------------------------
  // Tasks Auxiliares para Formatação e Verificação de Log
  // -------------------------------------------------------------------------
  task automatic log_section(input string title);
    $display("\n================================================================================");
    $display("  %s", title);
    $display("================================================================================");
  endtask

  task automatic check_rk(
    input string name,
    input logic [127:0] obtained,
    input logic [127:0] expected
  );
    total_tests++;
    if (obtained === expected) begin
      passed_tests++;
      $display("  [PASS] Teste %02d | %-28s", total_tests, name);
      $display("         Obtido:   0x%032h", obtained);
    end else begin
      failed_tests++;
      $display("  [FAIL] Teste %02d | %-28s", total_tests, name);
      $display("         Obtido:   0x%032h", obtained);
      $display("         Esperado: 0x%032h", expected);
    end
  endtask

  // -------------------------------------------------------------------------
  // Task Principal de Execução dos Vetores de Chave
  // -------------------------------------------------------------------------
  task automatic run(input logic [127:0] k, input logic [127:0] exp_rk [0:10], input string name);
    int cyc = 0;

    log_section($sformatf("SUÍTE DE TESTE: Expansão de Chave - %s", name));
    $display("  Chave Inicial Injetada (Key 0) : 0x%032h", k);
    $display("  Iniciando processo de geração de Round Keys (10 ciclos)...");

    key = k; start = 1; @(posedge clk); #1; start = 0;

    while (!ready && cyc < 40) begin
      @(posedge clk); #1; cyc++;
    end

    total_tests++;
    if (cyc == 10) begin
      passed_tests++;
      $display("\n  [PASS] Teste %02d | Latência de Expansão (10 ciclos atingidos com sucesso)", total_tests);
    end else begin
      failed_tests++;
      $display("\n  [FAIL] Teste %02d | Latência Incorreta: %0d ciclos (Esperado: 10 ciclos)", total_tests, cyc);
    end

    $display("\n  --- Verificação em Ordem Inversa (Leitura de Decifragem: RK10 -> RK0) ---");
    for (int i = 10; i >= 0; i--) begin
      sel = i[3:0]; #1;
      check_rk($sformatf("%s - RK[%02d] (Decifra)", name, i), rk, exp_rk[i]);
    end

    $display("\n  --- Verificação em Ordem Direta (Leitura de Cifragem: RK0 -> RK10) ---");
    for (int i = 0; i <= 10; i++) begin
      sel = i[3:0]; #1;
      check_rk($sformatf("%s - RK[%02d] (Cifra)", name, i), rk, exp_rk[i]);
    end
  endtask

  // -------------------------------------------------------------------------
  // Sequência Principal da Simulação
  // -------------------------------------------------------------------------
  logic [127:0] exp_b [0:10], exp_c [0:10];

  initial begin
    for (int i = 0; i <= 10; i++) begin
      exp_b[i] = APPB_RK[i];
      exp_c[i] = APPC_RK[i];
    end

    log_section("MINISOC AES - TESTBENCH DE VALIDAÇÃO DO KEY EXPANSION");
    $display("  Iniciando validação do gerador de sub-chaves para cifragem e decifragem...");

    repeat (3) @(posedge clk); #1; rst_n = 1; @(posedge clk); #1;

    // Teste de Sanidade de Reset
    total_tests++;
    if (ready || busy) begin
      failed_tests++;
      $display("  [FAIL] Teste %02d | Estado pós-Reset (busy=%b, ready=%b - Esperado: 0, 0)", total_tests, busy, ready);
    end else begin
      passed_tests++;
      $display("  [PASS] Teste %02d | Estado pós-Reset (Mantido em IDLE corretamente)", total_tests);
    end

    // Executa as suítes de teste FIPS-197
    run(128'h2b7e151628aed2a6abf7158809cf4f3c, exp_b, "FIPS-A.1/B");
    run(128'h000102030405060708090a0b0c0d0e0f, exp_c, "FIPS-C.1");

    // -------------------------------------------------------------------------
    // Relatório Final
    // -------------------------------------------------------------------------
    log_section("RESUMO DO TESTE DE KEY EXPANSION");
    $display("  Total de verificações efetuadas : %0d", total_tests);
    $display("  Verificações com SUCESSO (PASS) : %0d", passed_tests);
    $display("  Verificações com FALHA   (FAIL) : %0d", failed_tests);
    $display("--------------------------------------------------------------------------------");

    if (failed_tests == 0) begin
      $display("  RESULTADO FINAL: [ PASS ] - TODAS AS ROUND KEYS E MÉTRICAS FORAM VALIDADAS!\n");
    end else begin
      $display("  RESULTADO FINAL: [ FAIL ] - ENCONTRADAS DIVERGÊNCIAS NA EXPANSÃO DE CHAVE.\n");
      $stop;
    end

    $finish;
  end

endmodule