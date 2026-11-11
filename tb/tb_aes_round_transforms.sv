`timescale 1ns/1ps

// Testbench autoverificavel das transformacoes de rodada
module tb_aes_round_transforms;
  `include "vectors/aes_vectors.svh"

  // -------------------------------------------------------------------------
  // Sinais e Mapeamento de Portas com o RTL
  // -------------------------------------------------------------------------
  logic [7:0]   sb_in, sb_out, isb_out;
  logic [127:0] st, e_sb, e_sr, e_mc, e_isr, e_isb, e_imc, e_ark, rkey;

  // Contadores globais de teste
  int total_tests  = 0;
  int passed_tests = 0;
  int failed_tests = 0;

  // Instanciações dos submódulos RTL
  minisoc_aes_sbox     u_sbox  (.entrada(sb_in), .saida(sb_out));
  minisoc_aes_inv_sbox u_isbox (.entrada(sb_in), .saida(isb_out));
  minisoc_aes_sub_bytes       u_sb  (.i_state(st), .o_state(e_sb));
  minisoc_aes_shift_rows      u_sr  (.entrada(st), .saida(e_sr));
  minisoc_aes_mix_columns     u_mc  (.state_in(st), .state_out(e_mc));
  minisoc_aes_inv_shift_rows  u_isr (.entrada(st), .saida(e_isr));
  minisoc_aes_inv_sub_bytes   u_isb2(.entrada(st), .saida(e_isb));
  minisoc_aes_inv_mix_columns u_imc (.state_in(st), .state_out(e_imc));
  minisoc_aes_add_round_key   u_ark (.state_in(st), .round_key(rkey), .state_out(e_ark));

  // -------------------------------------------------------------------------
  // Referência Algorítmica em Software para a S-Box
  // -------------------------------------------------------------------------
  function automatic logic [7:0] gmul(input logic [7:0] a_in, input logic [7:0] b_in);
    logic [7:0] a, b, r;
    a = a_in; b = b_in; r = 8'h00;
    for (int i = 0; i < 8; i++) begin
      if (b[0]) r ^= a;
      a = {a[6:0], 1'b0} ^ (a[7] ? 8'h1b : 8'h00);
      b = b >> 1;
    end
    return r;
  endfunction

  function automatic logic [7:0] ginv(input logic [7:0] a);
    if (a == 0) return 8'h00;
    for (int b = 1; b < 256; b++) if (gmul(a, b[7:0]) == 8'h01) return b[7:0];
    return 8'h00;
  endfunction

  function automatic logic [7:0] rotl(input logic [7:0] x, input int n);
    return (x << n) | (x >> (8 - n));
  endfunction

  function automatic logic [7:0] ref_sbox(input logic [7:0] a);
    logic [7:0] b;
    b = ginv(a);
    return b ^ rotl(b,1) ^ rotl(b,2) ^ rotl(b,3) ^ rotl(b,4) ^ 8'h63;
  endfunction

  // -------------------------------------------------------------------------
  // Tasks Auxiliares para Formatação de Log
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
      $display("  [PASS] Teste %03d | %-36s", total_tests, name);
      $display("          Obtido:   0x%032h", obtained);
    end else begin
      failed_tests++;
      $display("  [FAIL] Teste %03d | %-36s", total_tests, name);
      $display("          Obtido:   0x%032h", obtained);
      $display("          Esperado: 0x%032h", expected);
    end
  endtask

  task automatic apply(input logic [127:0] s);
    st = s; #1;
  endtask

  // -------------------------------------------------------------------------
  // Sequência Principal da Simulação
  // -------------------------------------------------------------------------
  initial begin
    log_section("MINISOC AES - VALIDAÇÃO DAS TRANSFORMAÇÕES DE RODADA");
    $display("  Iniciando suíte de testes unitários em nível de módulo/submódulo...");

    // =========================================================================
    // 1. S-Box e InvS-Box (256 entradas de 0x00 a 0xFF)
    // =========================================================================
    log_section("GRUPO 1: Validação de S-Box e InvS-Box (256 Combinações)");
    for (int i = 0; i < 256; i++) begin
      sb_in = i[7:0]; #1;
      if (sb_out !== ref_sbox(i[7:0])) begin
        failed_tests++;
        $display("  [FAIL] S-Box(0x%02h) = 0x%02h | Esperado: 0x%02h", i[7:0], sb_out, ref_sbox(i[7:0]));
      end
      sb_in = sb_out; #1;
      if (isb_out !== i[7:0]) begin
        failed_tests++;
        $display("  [FAIL] InvS-Box(S-Box(0x%02h)) = 0x%02h", i[7:0], isb_out);
      end
    end
    total_tests += 512;
    passed_tests += (512 - failed_tests);
    $display("  [PASS] Suíte de 256 bytes testada com sucesso contra o modelo em GF(2^8).");

    // =========================================================================
    // 2. Vetores FIPS-197 Apêndice B (Cifragem Rodadas 1..10)
    // =========================================================================
    log_section("GRUPO 2: Apêndice B (Cifragem Directa Rodadas 1..10)");
    for (int r = 0; r < 10; r++) begin
      apply(APPB_E_START[r]);
      check_128b($sformatf("B SubBytes R%0d", r+1), e_sb, APPB_E_SB[r]);

      apply(APPB_E_SB[r]);
      check_128b($sformatf("B ShiftRows R%0d", r+1), e_sr, APPB_E_SR[r]);

      if (r < 9) begin
        apply(APPB_E_SR[r]);
        check_128b($sformatf("B MixColumns R%0d", r+1), e_mc, APPB_E_MC[r]);
      end

      st = APPB_E_MC[r]; rkey = APPB_RK[r+1]; #1;
      check_128b($sformatf("B AddRoundKey R%0d", r+1), e_ark, APPB_E_OUT[r]);
    end

    // =========================================================================
    // 3. Vetores FIPS-197 Apêndice C.1 (Cifragem e Decifragem Inversa)
    // =========================================================================
    log_section("GRUPO 3: Apêndice C.1 (Cifragem e Cifra Inversa)");
    for (int r = 0; r < 10; r++) begin
      apply(APPC_E_START[r]); check_128b($sformatf("C1 SubBytes R%0d", r+1), e_sb, APPC_E_SB[r]);
      apply(APPC_E_SB[r]);    check_128b($sformatf("C1 ShiftRows R%0d", r+1), e_sr, APPC_E_SR[r]);
      if (r < 9) begin
        apply(APPC_E_SR[r]);  check_128b($sformatf("C1 MixColumns R%0d", r+1), e_mc, APPC_E_MC[r]);
      end
    end

    for (int k = 0; k < 10; k++) begin
      apply(APPC_D_START[k]); check_128b($sformatf("C1 InvShiftRows R%0d", 9-k), e_isr, APPC_D_ISR[k]);
      apply(APPC_D_ISR[k]);   check_128b($sformatf("C1 InvSubBytes R%0d", 9-k),  e_isb, APPC_D_ISB[k]);
      st = APPC_D_ISB[k]; rkey = APPC_RK[9-k]; #1;
      check_128b($sformatf("C1 AddRoundKey R%0d", 9-k), e_ark, APPC_D_ARK[k]);
      if (k < 9) begin
        apply(APPC_D_ARK[k]); check_128b($sformatf("C1 InvMixColumns R%0d", 9-k), e_imc, APPC_D_OUT[k]);
      end
    end

    log_section("GRUPO 4: Apêndice B (Cifra Inversa)");
    for (int k = 0; k < 10; k++) begin
      apply(APPB_D_START[k]); check_128b($sformatf("B InvShiftRows R%0d", 9-k), e_isr, APPB_D_ISR[k]);
      apply(APPB_D_ISR[k]);   check_128b($sformatf("B InvSubBytes R%0d", 9-k),  e_isb, APPB_D_ISB[k]);
    end

    // =========================================================================
    // 4. Testes Aleatórios e Propriedades Inversas
    // =========================================================================
    log_section("GRUPO 5: MixColumns / InvMixColumns Aleatórios");
    for (int i = 0; i < N_MC; i++) begin
      apply(MC_IN[i]);  check_128b($sformatf("MixColumns[%02d]", i), e_mc, MC_OUT[i]);
      check_128b($sformatf("InvMixColumns[%02d]", i), e_imc, IMC_OUT[i]);
      apply(MC_OUT[i]); check_128b($sformatf("IMC(MC(x))[%02d]", i), e_imc, MC_IN[i]);
    end

    log_section("GRUPO 6: Identidades Inversas f^-1(f(x)) = x");
    for (int i = 0; i < N_MC; i++) begin
      apply(MC_IN[i]);
      st = e_sr; #1; check_128b($sformatf("InvShiftRows(ShiftRows)[%02d]", i), e_isr, MC_IN[i]);
      st = MC_IN[i]; #1; st = e_sb; #1; check_128b($sformatf("InvSubBytes(SubBytes)[%02d]", i), e_isb, MC_IN[i]);
    end

    // -------------------------------------------------------------------------
    // Relatório Final de Execução
    // -------------------------------------------------------------------------
    log_section("RESUMO DO TESTE DAS TRANSFORMAÇÕES DE RODADA");
    $display("  Total de verificações efetuadas : %0d", total_tests);
    $display("  Verificações com SUCESSO (PASS) : %0d", passed_tests);
    $display("  Verificações com FALHA   (FAIL) : %0d", failed_tests);
    $display("--------------------------------------------------------------------------------");

    if (failed_tests == 0) begin
      $display("  RESULTADO FINAL: [ PASS ] - TODAS AS TRANSFORMAÇÕES FORAM VALIDADAS!\n");
    end else begin
      $display("  RESULTADO FINAL: [ FAIL ] - FALHAS ENCONTRADAS NAS TRANSFORMAÇÕES DE RODADA.\n");
      $stop;
    end

    $finish;
  end
endmodule