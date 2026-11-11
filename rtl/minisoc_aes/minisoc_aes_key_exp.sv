// -----------------------------------------------------------------------------
// minisoc_aes_key_exp : expansao de chave AES-128 (FIPS-197, 5.2).
// Estrategia: PRE-COMPUTADA e sequencial (1 round key por ciclo, 4 S-boxes
// compartilhadas). 11 round keys ficam em um banco 11x128 lido de forma
// combinacional por i_rk_sel, em qualquer ordem (cifra: 0->10, decifra: 10->0).
// Latencia: 10 ciclos apos i_start. Novo i_start so e aceito com o_busy=0.
// Convencao: w0 = key[127:96] ... w3 = key[31:0]; round key r = {w4r..w4r+3}.
// -----------------------------------------------------------------------------
module minisoc_aes_key_exp
  import minisoc_aes_gf_pkg::*;
(
  input  logic         clk,
  input  logic         rst_n,
  input  logic         i_start,       // pulso: captura i_key e inicia a expansao
  input  logic [127:0] i_key,
  output logic         o_busy,
  output logic         o_ready,       // 1 = banco de round keys valido
  input  logic [3:0]   i_rk_sel,      // 0..10
  output logic [127:0] o_rk
);
  logic [127:0] rk_mem [0:10];
  logic [3:0]   round;                // proxima round key a calcular (1..10)
  logic [7:0]   rcon;

  logic [127:0] prev;
  logic [31:0]  rot_w, sub_w;
  logic [31:0]  t, n0, n1, n2, n3;

  assign prev  = rk_mem[round - 4'd1];
  assign rot_w = {prev[23:0], prev[31:24]};                 // RotWord(w3)

  for (genvar b = 0; b < 4; b++) begin : g_sw
    minisoc_aes_sbox u_sbox (.entrada(rot_w[31-8*b -: 8]), .saida(sub_w[31-8*b -: 8]));
  end

  assign t  = sub_w ^ {rcon, 24'h0};
  assign n0 = prev[127:96] ^ t;
  assign n1 = prev[95:64]  ^ n0;
  assign n2 = prev[63:32]  ^ n1;
  assign n3 = prev[31:0]   ^ n2;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      o_busy  <= 1'b0;
      o_ready <= 1'b0;
      round   <= 4'd1;
      rcon    <= 8'h01;
    end else if (!o_busy) begin
      if (i_start) begin
        o_busy  <= 1'b1;
        o_ready <= 1'b0;
        round   <= 4'd1;
        rcon    <= 8'h01;
      end
    end else begin
      if (round == 4'd10) begin
        o_busy  <= 1'b0;
        o_ready <= 1'b1;
      end else begin
        round <= round + 4'd1;
        rcon  <= xtime(rcon);
      end
    end
  end

  // Banco sem reset (conteudo so e valido quando o_ready=1).
  always_ff @(posedge clk) begin
    if (!o_busy && i_start)       rk_mem[0]     <= i_key;
    else if (o_busy)              rk_mem[round] <= {n0, n1, n2, n3};
  end

  assign o_rk = rk_mem[i_rk_sel];
endmodule
