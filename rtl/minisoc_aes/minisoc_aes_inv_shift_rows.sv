// InvShiftRows (opcional): linha r rotaciona à direita r posições.
module minisoc_aes_inv_shift_rows (
    input  logic [127:0] entrada,
    output logic [127:0] saida
);
  for (genvar n = 0; n < 16; n++) 
    begin
      localparam int R   = n % 4;
      localparam int C   = n / 4;
      localparam int result = R + 4 * ((C + 4 - R) % 4);
      assign saida[127-8*n -: 8] = entrada[127-8*result -: 8];
    end
endmodule

