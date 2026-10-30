// ShiftRows: só reordenação de fios. Byte n = s[r][c], r = n%4, c = n/4; s'[r][c] = s[r][(c+r) mod 4].
module minisoc_aes_shift_rows (
    input  logic [127:0] entrada,
    output logic [127:0] saida
);
  for (genvar n = 0; n < 16; n++) begin : g_sr
    localparam int R   = n % 4;
    localparam int C   = n / 4;
    localparam int SRC = R + 4 * ((C + R) % 4);
    assign saida[127-8*n -: 8] = entrada[127-8*SRC -: 8];
  end
endmodule
