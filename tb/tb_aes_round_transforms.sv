`timescale 1ns/1ps
// Testbench autoverificavel das transformacoes de rodada (Semanas 2 e 3).
//  (a) S-box e InvS-box nas 256 entradas vs. referencia algoritmica (inversa em GF + afim)
//  (b) SubBytes/ShiftRows/MixColumns/AddRoundKey e inversas nos vetores da FIPS-197 (Apendices B e C.1), rodadas 1..10
//  (c) MixColumns/InvMixColumns em 32 vetores aleatorios (modelo Python)
module tb_aes_round_transforms;
  `include "vectors/aes_vectors.svh"

  int errors = 0;
  task automatic check(input string what, input logic [127:0] got, input logic [127:0] exp);
    if (got !== exp) begin
      errors++;
      $display("FAIL %s: got=%032h exp=%032h", what, got, exp);
    end
  endtask

  // ---------------- referencia algoritmica da S-box
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

  // ---------------- DUTs
  logic [7:0]   sb_in, sb_out, isb_out;
  logic [127:0] st, e_sb, e_sr, e_mc, e_isr, e_isb, e_imc, e_ark, e_arkk, rkey;

  minisoc_aes_sbox     u_sbox  (.i_byte(sb_in), .o_byte(sb_out));
  minisoc_aes_inv_sbox u_isbox (.i_byte(sb_in), .o_byte(isb_out));
  minisoc_aes_sub_bytes       u_sb  (.i_state(st), .o_state(e_sb));
  minisoc_aes_shift_rows      u_sr  (.i_state(st), .o_state(e_sr));
  minisoc_aes_mix_columns     u_mc  (.i_state(st), .o_state(e_mc));
  minisoc_aes_inv_shift_rows  u_isr (.i_state(st), .o_state(e_isr));
  minisoc_aes_inv_sub_bytes   u_isb2(.i_state(st), .o_state(e_isb));
  minisoc_aes_inv_mix_columns u_imc (.i_state(st), .o_state(e_imc));
  minisoc_aes_add_round_key   u_ark (.i_state(st), .i_round_key(rkey), .o_state(e_ark));

  task automatic apply(input logic [127:0] s);  st = s; #1; endtask

  initial begin
    $display("== (a) S-box / InvS-box: 256 entradas");
    for (int i = 0; i < 256; i++) begin
      sb_in = i[7:0]; #1;
      if (sb_out !== ref_sbox(i[7:0])) begin errors++; $display("FAIL sbox(%02h)=%02h exp %02h", i[7:0], sb_out, ref_sbox(i[7:0])); end
      sb_in = sb_out; #1;
      if (isb_out !== i[7:0]) begin errors++; $display("FAIL invsbox(sbox(%02h))=%02h", i[7:0], isb_out); end
    end
    sb_in = 8'h00; #1; if (sb_out !== 8'h63) begin errors++; $display("FAIL sbox(00)"); end
    sb_in = 8'h53; #1; if (sb_out !== 8'hed) begin errors++; $display("FAIL sbox(53)"); end

    $display("== (b) Apendice B (cifragem): rodadas 1..10");
    for (int r = 0; r < 10; r++) begin
      apply(APPB_E_START[r]);
      check($sformatf("B SubBytes r%0d", r+1),   e_sb, APPB_E_SB[r]);
      apply(APPB_E_SB[r]);
      check($sformatf("B ShiftRows r%0d", r+1),  e_sr, APPB_E_SR[r]);
      if (r < 9) begin
        apply(APPB_E_SR[r]);
        check($sformatf("B MixColumns r%0d", r+1), e_mc, APPB_E_MC[r]);
      end
      st = APPB_E_MC[r]; rkey = APPB_RK[r+1]; #1;
      check($sformatf("B AddRoundKey r%0d", r+1), e_ark, APPB_E_OUT[r]);
    end
    $display("== (b) Apendice C.1 (cifragem e cifra inversa)");
    for (int r = 0; r < 10; r++) begin
      apply(APPC_E_START[r]); check($sformatf("C1 SubBytes r%0d", r+1), e_sb, APPC_E_SB[r]);
      apply(APPC_E_SB[r]);    check($sformatf("C1 ShiftRows r%0d", r+1), e_sr, APPC_E_SR[r]);
      if (r < 9) begin apply(APPC_E_SR[r]); check($sformatf("C1 MixColumns r%0d", r+1), e_mc, APPC_E_MC[r]); end
    end
    for (int k = 0; k < 10; k++) begin  // k=0 -> rodada 9 ... k=9 -> rodada 0
      apply(APPC_D_START[k]); check($sformatf("C1 InvShiftRows r%0d", 9-k), e_isr, APPC_D_ISR[k]);
      apply(APPC_D_ISR[k]);   check($sformatf("C1 InvSubBytes r%0d", 9-k),  e_isb, APPC_D_ISB[k]);
      st = APPC_D_ISB[k]; rkey = APPC_RK[9-k]; #1;
      check($sformatf("C1 AddRoundKey r%0d", 9-k), e_ark, APPC_D_ARK[k]);
      if (k < 9) begin apply(APPC_D_ARK[k]); check($sformatf("C1 InvMixColumns r%0d", 9-k), e_imc, APPC_D_OUT[k]); end
    end
    $display("== (b) Apendice B (cifra inversa)");
    for (int k = 0; k < 10; k++) begin
      apply(APPB_D_START[k]); check($sformatf("B InvShiftRows r%0d", 9-k), e_isr, APPB_D_ISR[k]);
      apply(APPB_D_ISR[k]);   check($sformatf("B InvSubBytes r%0d", 9-k),  e_isb, APPB_D_ISB[k]);
    end

    $display("== (c) MixColumns / InvMixColumns aleatorios");
    for (int i = 0; i < N_MC; i++) begin
      apply(MC_IN[i]);  check($sformatf("MC[%0d]", i),  e_mc,  MC_OUT[i]);
      check($sformatf("IMC[%0d]", i), e_imc, IMC_OUT[i]);
      apply(MC_OUT[i]); check($sformatf("IMC(MC(x))[%0d]", i), e_imc, MC_IN[i]);
    end
    $display("== InvShiftRows(ShiftRows(x)) = x e InvSubBytes(SubBytes(x)) = x");
    for (int i = 0; i < N_MC; i++) begin
      apply(MC_IN[i]);
      st = e_sr; #1; check($sformatf("ISR(SR[%0d])", i), e_isr, MC_IN[i]);
      st = MC_IN[i]; #1; st = e_sb; #1; check($sformatf("ISB(SB[%0d])", i), e_isb, MC_IN[i]);
    end

    if (errors == 0) $display("PASS: tb_aes_round_transforms (0 erros)");
    else             $display("FAIL: tb_aes_round_transforms (%0d erros)", errors);
    $finish;
  end
endmodule
