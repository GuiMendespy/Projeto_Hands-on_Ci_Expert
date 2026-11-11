`timescale 1ns/1ps

// Testbench autoverificavel de minisoc_aes_dp (Datapath completo do AES-128)
module tb_aes_dp;
  `include "vectors/aes_vectors.svh"

  // -------------------------------------------------------------------------
  // Sinais de Interface
  // -------------------------------------------------------------------------
  logic clk = 0, rst_n = 0;
  logic [127:0] key, block_in, block_out;
  logic key_load = 0, key_ready, start = 0, decrypt = 0, busy, done;

  // Contadores globais de teste
  int total_tests  = 0;
  int passed_tests = 0;
  int failed_tests = 0;

  always #5 clk = ~clk;

  // Instanciação do DUT (Datapath Top-Level)
  minisoc_aes_dp dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .i_key        (key),
    .i_key_load   (key_load),
    .o_key_ready  (key_ready),
    .i_start      (start),
    .i_decrypt    (decrypt),
    .i_block      (block_in),
    .o_block      (block_out),
    .o_busy       (busy),
    .o_done       (done)
  );

  // -------------------------------------------------------------------------
  // Tasks Auxiliares para Formatação de Logs
  // -------------------------------------------------------------------------
  task automatic log_section(input string title);
    $display("\n================================================================================");
    $display("  %s", title);
    $display("================================================================================");
  endtask

  task automatic check_128b(
    input string name,
    input logic [127:0] obtained,
    input logic [127:0] expected
  );
    total_tests++;
    if (obtained === expected) begin
      passed_tests++;
      $display("  [PASS] Teste %02d | %-36s", total_tests, name);
      $display("         Obtido:   0x%032h", obtained);
    end else begin
      failed_tests++;
      $display("  [FAIL] Teste %02d | %-36s", total_tests, name);
      $display("         Obtido:   0x%032h", obtained);
      $display("         Esperado: 0x%032h", expected);
    end
  endtask

  task automatic load_key(input logic [127:0] k);
    int t;
    key = k; key_load = 1; @(posedge clk); #1; key_load = 0;
    t = 0;
    while (!key_ready && t < 100) begin @(posedge clk); #1; t++; end
    total_tests++;
    if (!key_ready) begin
      failed_tests++;
      $display("  [FAIL] Teste %02d | Carregamento de Chave (Timeout key_ready)", total_tests);
    end else begin
      passed_tests++;
      $display("  [PASS] Teste %02d | Carregamento de Chave (Key Ready OK)", total_tests);
      $display("         Chave:    0x%032h", k);
    end
    @(posedge clk); #1;
  endtask

  task automatic run_block(
    input logic [127:0] din,
    input logic dec,
    output logic [127:0] dout,
    output int cycles
  );
    block_in = din; decrypt = dec; start = 1; cycles = 0;
    @(posedge clk); #1; start = 0;
    while (!done && cycles < 50) begin @(posedge clk); #1; cycles++; end
    dout = block_out;
    if (cycles >= 50) begin
      $display("  [WARNING] Timeout aguardando o_done (>= 50 ciclos)");
    end
  endtask

  // -------------------------------------------------------------------------
  // Sequência Principal da Simulação
  // -------------------------------------------------------------------------
  logic [127:0] r;
  int cyc;

  initial begin
    log_section("MINISOC AES - TESTBENCH DE VALIDAÇÃO DO DATAPATH (TB_AES_DP)");
    $display("  Iniciando testes funcionais e de latência para o núcleo AES-128...");

    repeat (3) @(posedge clk); #1; rst_n = 1; @(posedge clk); #1;

    // Teste 1: Proteção de Start sem chave válida
    block_in = 128'h0; start = 1; @(posedge clk); #1; start = 0; repeat (3) @(posedge clk);
    total_tests++;
    if (busy || done) begin
      failed_tests++;
      $display("  [FAIL] Teste %02d | Proteção de Start Sem Chave (Aceitou start indevidamente)", total_tests);
    end else begin
      passed_tests++;
      $display("  [PASS] Teste %02d | Proteção de Start Sem Chave (Ignorado com sucesso)", total_tests);
    end

    // Teste 2: FIPS-197 Apêndice C.1
    log_section("GRUPO 1: Validação FIPS-197 Apêndice C.1");
    load_key(128'h000102030405060708090a0b0c0d0e0f);
    
    run_block(128'h00112233445566778899aabbccddeeff, 0, r, cyc);
    check_128b("C.1 Cifragem (Encrypt)", r, 128'h69c4e0d86a7b0430d8cdb78070b4c55a);
    $display("         Latência Cifra: %0d ciclos", cyc);

    run_block(128'h69c4e0d86a7b0430d8cdb78070b4c55a, 1, r, cyc);
    check_128b("C.1 Decifragem (Decrypt)", r, 128'h00112233445566778899aabbccddeeff);
    $display("         Latência Decifra: %0d ciclos", cyc);

    // Teste 3: FIPS-197 Apêndice B
    log_section("GRUPO 2: Validação FIPS-197 Apêndice B");
    load_key(128'h2b7e151628aed2a6abf7158809cf4f3c);

    run_block(128'h3243f6a8885a308d313198a2e0370734, 0, r, cyc);
    check_128b("B Cifragem (Encrypt)", r, 128'h3925841d02dc09fbdc118597196a0b32);

    run_block(128'h3925841d02dc09fbdc118597196a0b32, 1, r, cyc);
    check_128b("B Decifragem (Decrypt)", r, 128'h3243f6a8885a308d313198a2e0370734);

    repeat (4) @(posedge clk);
    check_128b("Retenção de o_block pós-done", block_out, 128'h3243f6a8885a308d313198a2e0370734);

    // Teste 4: Vetores Aleatórios
    log_section($sformatf("GRUPO 3: Validação de %0d Vetores Aleatórios", N_RND));
    for (int i = 0; i < N_RND; i++) begin
      load_key(RND_KEY[i]);
      run_block(RND_PT[i], 0, r, cyc);
      check_128b($sformatf("RND[%02d] Cifragem", i), r, RND_CT[i]);

      run_block(RND_CT[i], 1, r, cyc);
      check_128b($sformatf("RND[%02d] Decifragem", i), r, RND_PT[i]);
    end

    // -------------------------------------------------------------------------
    // Relatório Final de Execução
    // -------------------------------------------------------------------------
    log_section("RESUMO DO TESTE DO DATAPATH (TB_AES_DP)");
    $display("  Total de verificações efetuadas : %0d", total_tests);
    $display("  Verificações com SUCESSO (PASS) : %0d", passed_tests);
    $display("  Verificações com FALHA   (FAIL) : %0d", failed_tests);
    $display("--------------------------------------------------------------------------------");

    if (failed_tests == 0) begin
      $display("  RESULTADO FINAL: [ PASS ] - DATAPATH AES VALIDADO COM SUCESSO!\n");
    end else begin
      $display("  RESULTADO FINAL: [ FAIL ] - FALHAS ENCONTRADAS NO DATAPATH.\n");
      $stop;
    end

    $finish;
  end
endmodule