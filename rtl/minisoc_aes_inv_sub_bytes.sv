// InvSubBytes (opcional): 16 instâncias da InvS-box.
module minisoc_aes_inv_sub_bytes (
    input  logic [127:0] entrada,
    output logic [127:0] saida
);
  for (genvar n = 0; n < 16; n++) 
    begin
      minisoc_aes_inv_sbox u_isbox (
          .i_byte(entrada[127-8*n -: 8]),
          .o_byte(saida[127-8*n -: 8])
      );
    end
endmodule
