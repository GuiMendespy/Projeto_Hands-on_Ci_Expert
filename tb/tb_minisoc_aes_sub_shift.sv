// Testbench autoverificavel simplificado para AES SubBytes, ShiftRows e Inversas
module tb_minisoc_aes_sub_shift;

  // Sinais de teste
  logic [7:0]   sb_in;
  logic [7:0]   sb_out, isb_out;
  logic [127:0] st_in;
  logic [127:0] sub_out, sr_out, isub_out, isr_out;

  // Instanciaces com mapeamento correto das portas do RTL
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

    $display("=== INICIANDO SIMULACAO DO AES SUBBYTES & SHIFTROWS ===");

    // 1. Verificacao das 256 entradas da S-Box e InvS-Box
    for (int i = 0; i < 256; i++) begin
      sb_in = 8'(i); #1;
      if (sb_out !== ref_sbox(8'(i))) begin
        $display("[ERRO] S-box[%02h]: Obtido = %02h | Esperado = %02h", 8'(i), sb_out, ref_sbox(8'(i)));
        errors++;
      end
      sb_in = sb_out; #1;
      if (isb_out !== 8'(i)) begin
        $display("[ERRO] InvS-box(S-box(%02h)) = %02h", 8'(i), isb_out);
        errors++;
      end
    end
    $display("[OK] S-box e InvS-box: 256 entradas validadas com sucesso.");

    // 2. Verificacao das Rodadas 1..10 (FIPS-197 Apendice B)
    for (int r = 0; r < 10; r++) begin
      st_in = v_start[r]; #1;
      if (sub_out !== v_sub[r]) begin
        $display("[ERRO] SubBytes Rodada %0d: Obtido = %h | Esperado = %h", r+1, sub_out, v_sub[r]);
        errors++;
      end
      if (isub_out !== v_start[r]) begin
        $display("[ERRO] InvSubBytes Rodada %0d falhou", r+1);
        errors++;
      end

      st_in = v_sub[r]; #1;
      if (sr_out !== v_sh[r]) begin
        $display("[ERRO] ShiftRows Rodada %0d: Obtido = %h | Esperado = %h", r+1, sr_out, v_sh[r]);
        errors++;
      end
      if (isr_out !== v_sub[r]) begin
        $display("[ERRO] InvShiftRows Rodada %0d falhou", r+1);
        errors++;
      end
    end
    $display("[OK] SubBytes, ShiftRows e Inversas validados nas 10 rodadas.");

    // Resultado final
    if (errors == 0)
      $display("\n=========================================\n === TESTES CONCLUIDOS COM SUCESSO (PASS) ===\n=========================================\n");
    else
      $display("\n=========================================\n === FALHA: %0d ERRO(S) ENCONTRADO(S) ===\n=========================================\n", errors);

    $finish;
  end
endmodule