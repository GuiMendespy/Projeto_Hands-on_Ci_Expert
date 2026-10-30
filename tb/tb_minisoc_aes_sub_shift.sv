// Testbench autoverificavel com logs detalhados para AES SubBytes, ShiftRows e Inversas
module tb_minisoc_aes_sub_shift;

  // Sinais de teste
  logic [7:0]   sb_in;
  logic [7:0]   sb_out, isb_out;
  logic [127:0] st_in;
  logic [127:0] sub_out, sr_out, isub_out, isr_out;

  // Instanciaçoes com mapeamento correto das portas do RTL
  minisoc_aes_sbox           u_sbox  (.entrada(sb_in),   .saida(sb_out));
  minisoc_aes_inv_sbox       u_isbox (.entrada(sb_in),   .saida(isb_out));
  minisoc_aes_sub_bytes      u_sub   (.i_state(st_in),   .o_state(sub_out));
  minisoc_aes_shift_rows     u_sr    (.entrada(st_in),   .saida(sr_out));
  minisoc_aes_inv_sub_bytes  u_isub  (.entrada(sub_out), .saida(isub_out));
  minisoc_aes_inv_shift_rows u_isr   (.entrada(sr_out),  .saida(isr_out));

  int errors = 0;
  logic [127:0] v_start [10];
  logic [127:0] v_sub   [10];
  logic [127:0] v_sh    [10];

  // Funcao de referencia em GF(2^8) para validacao da S-Box
  function automatic logic [7:0] gmul(logic [7:0] a_in, logic [7:0] b_in);
    logic [7:0] a = a_in, b = b_in, p = 8'h00;
    for (int k = 0; k < 8; k++) begin
      if (b[0]) p ^= a;
      a = {a[6:0], 1'b0} ^ (a[7] ? 8'h1b : 8'h00);
      b >>= 1;
    end
    return p;
  endfunction

  function automatic logic [7:0] ref_sbox(logic [7:0] x);
    logic [7:0] inv = 8'h00;
    for (int y = 1; y < 256; y++)
      if (gmul(x, 8'(y)) == 8'h01) inv = 8'(y);
    return inv ^ {inv[6:0], inv[7]} ^ {inv[5:0], inv[7:6]} ^ {inv[4:0], inv[7:5]}
               ^ {inv[3:0], inv[7:4]} ^ 8'h63;
  endfunction

  initial begin
    `include "aes_vectors.svh"

    $display("================================================================================");
    $display("               INICIANDO SIMULACAO DETALHADA: AES SUBBYTES & SHIFTROWS          ");
    $display("================================================================================");

    // --------------------------------------------------------------------------------
    // 1. TESTE DA S-BOX E INVS-BOX (256 valores de 0x00 a 0xFF)
    // --------------------------------------------------------------------------------
    $display("\n>>> TESTE 1: Validacao da S-Box e InvS-Box para as 256 combinaçoes de Bytes <<<");
    $display("--------------------------------------------------------------------------------");
    for (int i = 0; i < 256; i++) begin
      logic [7:0] expected_sbox;
      sb_in = 8'(i); 
      #1;
      expected_sbox = ref_sbox(8'(i));

      // Teste S-Box
      if (sb_out !== expected_sbox) begin
        $display("[ERRO S-BOX]   Entrada Injetada: 0x%02h | Saida RTL: 0x%02h | Esperado: 0x%02h", 8'(i), sb_out, expected_sbox);
        errors++;
      end else begin
        $display("[S-BOX OK]     Entrada Injetada: 0x%02h --> Saida RTL: 0x%02h (Esperado: 0x%02h)", 8'(i), sb_out, expected_sbox);
      end

      // Teste InvS-Box
      sb_in = sb_out; 
      #1;
      if (isb_out !== 8'(i)) begin
        $display("[ERRO INVS-BOX] Entrada Injetada: 0x%02h | Saida RTL: 0x%02h | Esperado: 0x%02h", sb_out, isb_out, 8'(i));
        errors++;
      end else begin
        $display("[INVS-BOX OK]  Entrada Injetada: 0x%02h --> Saida RTL: 0x%02h (Esperado: 0x%02h)", sb_in, isb_out, 8'(i));
      end
    end
    $display("--------------------------------------------------------------------------------");
    $display("[RESUMO TESTE 1] S-box e InvS-box validadas para todas as 256 combinaçoes.");

    // --------------------------------------------------------------------------------
    // 2. TESTE DAS RODADAS 1..10 (FIPS-197 Apendice B)
    // --------------------------------------------------------------------------------
    $display("\n>>> TESTE 2: Validacao de SubBytes, ShiftRows e Inversas nas 10 Rodadas <<<");
    $display("================================================================================");

    for (int r = 0; r < 10; r++) begin
      $display("\n--- RODADA %02d / 10 ---", r + 1);

      // (a) Teste SubBytes & InvSubBytes
      st_in = v_start[r]; 
      #1;
      $display("[INJECAO - SubBytes]    Estado de Entrada  : %h", st_in);
      $display("[SAIDA   - SubBytes]    Saida RTL          : %h", sub_out);
      $display("[ESPERADO- SubBytes]    Saida do Padrao    : %h", v_sub[r]);
      
      if (sub_out !== v_sub[r]) begin
        $display("  => [FALHA SUBBYTES] O resultado nao confere com o vetor padrao!");
        errors++;
      end else begin
        $display("  => [OK SUBBYTES] SubBytes executado com sucesso.");
      end

      $display("[SAIDA   - InvSubBytes] Saida Recuperada   : %h", isub_out);
      if (isub_out !== v_start[r]) begin
        $display("  => [FALHA INVSUBBYTES] Falha ao recuperar o estado original!");
        errors++;
      end else begin
        $display("  => [OK INVSUBBYTES] Estado reconstruido perfeitamente.");
      end

      // (b) Teste ShiftRows & InvShiftRows
      st_in = v_sub[r]; 
      #1;
      $display("\n[INJECAO - ShiftRows]   Estado de Entrada  : %h", st_in);
      $display("[SAIDA   - ShiftRows]   Saida RTL          : %h", sr_out);
      $display("[ESPERADO- ShiftRows]   Saida do Padrao    : %h", v_sh[r]);

      if (sr_out !== v_sh[r]) begin
        $display("  => [FALHA SHIFTROWS] O resultado nao confere com o vetor padrao!");
        errors++;
      end else begin
        $display("  => [OK SHIFTROWS] ShiftRows executado com sucesso.");
      end

      $display("[SAIDA   - InvShiftRows] Saida Recuperada  : %h", isr_out);
      if (isr_out !== v_sub[r]) begin
        $display("  => [FALHA INVSHIFTROWS] Falha ao recuperar o estado original!");
        errors++;
      end else begin
        $display("  => [OK INVSHIFTROWS] Estado reconstruido perfeitamente.");
      end
      $display("--------------------------------------------------------------------------------");
    end

    // --------------------------------------------------------------------------------
    // RESULTADO FINAL DA SIMULACAO
    // --------------------------------------------------------------------------------
    $display("\n================================================================================");
    if (errors == 0) begin
      $display("                 SIMULACAO CONCLUIDA COM SUCESSO! [PASS]");
      $display("                 Total de Erros Encontrados: %0d", errors);
    end else begin
      $display("                 SIMULACAO FINALIZADA COM ERROS! [FAIL]");
      $display("                 Total de Erros Encontrados: %0d", errors);
    end
    $display("================================================================================\n");

    $finish;
  end
endmodule