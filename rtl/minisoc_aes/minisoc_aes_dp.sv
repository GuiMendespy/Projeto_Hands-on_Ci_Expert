// -----------------------------------------------------------------------------
// minisoc_aes_dp : datapath AES-128, cifra e cifra inversa de 1 bloco.
// Microarquitetura iterativa: 1 rodada por ciclo.
//   Cifra  : ciclo 0 -> state = in ^ rk[0]; ciclos 1..10 -> rodadas 1..10.
//   Decifra: ciclo 0 -> state = in ^ rk[10]; ciclos 1..10 -> rodadas 9..0.
// Latencia de bloco: 11 ciclos entre i_start e o_done.
// Protocolo:
//   1) pulso i_key_load com i_key estavel -> espera o_key_ready=1 (~11 ciclos);
//   2) com o_key_ready=1 e o_busy=0: pulso i_start com i_block e i_decrypt;
//   3) o_done pulsa 1 ciclo; o_block e valido e mantido ate o proximo i_start.
// i_key_load e i_start sao ignorados enquanto o_busy ou a expansao estiverem ativos.
// -----------------------------------------------------------------------------
module minisoc_aes_dp (
  input  logic         clk,
  input  logic         rst_n,
  // chave
  input  logic [127:0] i_key,
  input  logic         i_key_load,
  output logic         o_key_ready,
  // bloco
  input  logic         i_start,
  input  logic         i_decrypt,    // 0 = cifra, 1 = cifra inversa
  input  logic [127:0] i_block,
  output logic [127:0] o_block,
  output logic         o_busy,
  output logic         o_done
);
  logic         ke_busy;
  logic [3:0]   rk_sel, round;
  logic [127:0] rk;
  logic         dec_q;
  logic [127:0] state;

  wire can_start = !o_busy && !ke_busy && o_key_ready;
  wire go        = i_start && can_start;

  minisoc_aes_key_exp u_key_exp (
    .clk(clk), .rst_n(rst_n),
    .i_start(i_key_load && !o_busy), .i_key(i_key),
    .o_busy(ke_busy), .o_ready(o_key_ready),
    .i_rk_sel(rk_sel), .o_rk(rk)
  );

  assign rk_sel = o_busy ? round : (i_decrypt ? 4'd10 : 4'd0);

  // ---- caminho da cifra
  logic [127:0] e_sb, e_sr, e_mc, e_next;
  minisoc_aes_sub_bytes     u_sb (.i_state(state), .o_state(e_sb));
  minisoc_aes_shift_rows    u_sr (.i_state(e_sb),  .o_state(e_sr));
  minisoc_aes_mix_columns   u_mc (.i_state(e_sr),  .o_state(e_mc));
  assign e_next = ((round == 4'd10) ? e_sr : e_mc) ^ rk;

  // ---- caminho da cifra inversa
  logic [127:0] d_isr, d_isb, d_ark, d_imc, d_next;
  minisoc_aes_inv_shift_rows  u_isr (.i_state(state), .o_state(d_isr));
  minisoc_aes_inv_sub_bytes   u_isb (.i_state(d_isr), .o_state(d_isb));
  minisoc_aes_add_round_key   u_ark (.i_state(d_isb), .i_round_key(rk), .o_state(d_ark));
  minisoc_aes_inv_mix_columns u_imc (.i_state(d_ark), .o_state(d_imc));
  assign d_next = (round == 4'd0) ? d_ark : d_imc;

  wire last = dec_q ? (round == 4'd0) : (round == 4'd10);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      o_busy <= 1'b0;
      o_done <= 1'b0;
      round  <= 4'd0;
      dec_q  <= 1'b0;
      state  <= '0;
    end else begin
      o_done <= 1'b0;
      if (!o_busy) begin
        if (go) begin
          o_busy <= 1'b1;
          dec_q  <= i_decrypt;
          round  <= i_decrypt ? 4'd9 : 4'd1;
          state  <= i_block ^ rk;                 // rk = rk[0] (cifra) ou rk[10] (decifra)
        end
      end else begin
        state <= dec_q ? d_next : e_next;
        if (last) begin
          o_busy <= 1'b0;
          o_done <= 1'b1;
        end else begin
          round <= dec_q ? round - 4'd1 : round + 4'd1;
        end
      end
    end
  end

  assign o_block = state;
endmodule
