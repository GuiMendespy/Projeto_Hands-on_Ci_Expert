// SubBytes: 16 instâncias da S-box. Byte 0 em [127:120], byte 15 em [7:0].
module minisoc_aes_sub_bytes (
    input  logic [127:0] i_state,
    output logic [127:0] o_state
);
  for (genvar n = 0; n < 16; n++) 
  begin
    minisoc_aes_sbox u_sbox (
        .entrada(i_state[127-8*n -: 8]),
        .saida(o_state[127-8*n -: 8])
    );
  end
endmodule
