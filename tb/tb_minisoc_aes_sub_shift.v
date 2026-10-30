// Testbench autoverificável: S-box (256 entradas), SubBytes/ShiftRows (FIPS-197 Apêndice B, rodadas 1..10)
// e inversas (opcional).
module tb_minisoc_aes_sub_shift;
  reg  [7:0]   sb_in;   wire [7:0]   sb_out, isb_out;
  reg  [127:0] st_in;   wire [127:0] sub_out, sr_out, isub_out, isr_out;
  wire [127:0] sub_sr_in_rt, sr_isr_rt;

  minisoc_aes_sbox          u_sbox  (.i_byte(sb_in), .o_byte(sb_out));
  minisoc_aes_inv_sbox      u_isbox (.i_byte(sb_in), .o_byte(isb_out));
  minisoc_aes_sub_bytes     u_sub   (.i_state(st_in), .o_state(sub_out));
  minisoc_aes_shift_rows    u_sr    (.i_state(st_in), .o_state(sr_out));
  minisoc_aes_inv_sub_bytes u_isub  (.i_state(sub_out), .o_state(isub_out));
  minisoc_aes_inv_shift_rows u_isr  (.i_state(sr_out),  .o_state(isr_out));

  integer errors, i, r;
  reg [127:0] v_start [0:9];
  reg [127:0] v_sub   [0:9];
  reg [127:0] v_sh    [0:9];

  // Referência independente da tabela do DUT: inversa em GF(2^8) + transformação afim.
  function [7:0] gmul(input [7:0] a_in, input [7:0] b_in);
    reg [7:0] a, b, p; integer k;
    begin
      a = a_in; b = b_in; p = 8'h00;
      for (k = 0; k < 8; k = k + 1) begin
        if (b[0]) p = p ^ a;
        a = {a[6:0], 1'b0} ^ (a[7] ? 8'h1b : 8'h00);
        b = b >> 1;
      end
      gmul = p;
    end
  endfunction

  function [7:0] ref_sbox(input [7:0] x);
    reg [7:0] inv; integer y;
    begin
      inv = 8'h00;
      for (y = 1; y < 256; y = y + 1)
        if (gmul(x, y[7:0]) == 8'h01) inv = y[7:0];
      ref_sbox = inv ^ {inv[6:0], inv[7]} ^ {inv[5:0], inv[7:6]} ^ {inv[4:0], inv[7:5]}
                     ^ {inv[3:0], inv[7:4]} ^ 8'h63;
    end
  endfunction

  initial begin
    errors = 0;
`include "aes_vectors.vh"

    // (a) S-box nas 256 entradas + inversa
    for (i = 0; i < 256; i = i + 1) begin
      sb_in = i[7:0]; #1;
      if (sb_out !== ref_sbox(i[7:0])) begin
        $display("FAIL sbox[%02h]: got %02h exp %02h", i[7:0], sb_out, ref_sbox(i[7:0]));
        errors = errors + 1;
      end
      sb_in = sb_out; #1;
      if (isb_out !== i[7:0]) begin
        $display("FAIL inv_sbox(sbox(%02h)) = %02h", i[7:0], isb_out);
        errors = errors + 1;
      end
    end
    sb_in = 8'h00; #1; if (sb_out !== 8'h63) begin $display("FAIL sbox(00)"); errors = errors + 1; end
    sb_in = 8'h53; #1; if (sb_out !== 8'hed) begin $display("FAIL sbox(53)"); errors = errors + 1; end
    $display("S-box: 256 entradas verificadas");

    // (b) SubBytes / ShiftRows nas rodadas 1..10 (Apêndice B) + inversas
    for (r = 0; r < 10; r = r + 1) begin
      st_in = v_start[r]; #1;
      if (sub_out !== v_sub[r]) begin
        $display("FAIL SubBytes rodada %0d: got %h exp %h", r+1, sub_out, v_sub[r]); errors = errors + 1;
      end
      st_in = v_sub[r]; #1;
      if (sr_out !== v_sh[r]) begin
        $display("FAIL ShiftRows rodada %0d: got %h exp %h", r+1, sr_out, v_sh[r]); errors = errors + 1;
      end
      st_in = v_start[r]; #1;
      if (isub_out !== v_start[r]) begin
        $display("FAIL InvSubBytes(SubBytes(x)) rodada %0d", r+1); errors = errors + 1;
      end
      if (isr_out !== v_start[r]) begin
        $display("FAIL InvShiftRows(ShiftRows(x)) rodada %0d", r+1); errors = errors + 1;
      end
      $display("Rodada %0d: SubBytes/ShiftRows/inversas conferidos", r+1);
    end

    if (errors == 0) $display("PASS");
    else             $display("FAIL: %0d erro(s)", errors);
    $finish;
  end
endmodule
