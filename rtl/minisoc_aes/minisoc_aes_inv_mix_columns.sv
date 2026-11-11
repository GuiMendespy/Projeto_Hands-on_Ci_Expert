`timescale 1ns/1ps

module minisoc_aes_inv_mix_columns (
    input  logic [127:0] state_in,
    output logic [127:0] state_out
);

    // -------------------------------------------------------------------------
    // Funções auxiliares para multiplicação em GF(2^8) pelo polinômio 0x11B
    // -------------------------------------------------------------------------
    function automatic logic [7:0] xtime(input logic [7:0] b);
        return (b[7]) ? ((b << 1) ^ 8'h1b) : (b << 1);
    endfunction

    // Multiplicações por {09, 0B, 0D, 0E} decompostas em potências de 2
    function automatic logic [7:0] gmul_09(input logic [7:0] b);
        return xtime(xtime(xtime(b))) ^ b; // (8 ^ 1)
    endfunction

    function automatic logic [7:0] gmul_0b(input logic [7:0] b);
        return xtime(xtime(xtime(b))) ^ xtime(b) ^ b; // (8 ^ 2 ^ 1)
    endfunction

    function automatic logic [7:0] gmul_0d(input logic [7:0] b);
        return xtime(xtime(xtime(b))) ^ xtime(xtime(b)) ^ b; // (8 ^ 4 ^ 1)
    endfunction

    function automatic logic [7:0] gmul_0e(input logic [7:0] b);
        return xtime(xtime(xtime(b))) ^ xtime(xtime(b)) ^ xtime(b); // (8 ^ 4 ^ 2)
    endfunction

    // -------------------------------------------------------------------------
    // Aplicação da Matriz Inversa (FIPS-197) em cada uma das 4 colunas
    // -------------------------------------------------------------------------
    always_comb begin
        for (int i = 0; i < 4; i++) begin
            logic [7:0] s0, s1, s2, s3;
            
            // Leitura dos 4 bytes da coluna 'i'
            s0 = state_in[127 - 32*i      -: 8];
            s1 = state_in[127 - 32*i - 8  -: 8];
            s2 = state_in[127 - 32*i - 16 -: 8];
            s3 = state_in[127 - 32*i - 24 -: 8];

            // Transformação pela matriz de constantes
            state_out[127 - 32*i      -: 8] = gmul_0e(s0) ^ gmul_0b(s1) ^ gmul_0d(s2) ^ gmul_09(s3);
            state_out[127 - 32*i - 8  -: 8] = gmul_09(s0) ^ gmul_0e(s1) ^ gmul_0b(s2) ^ gmul_0d(s3);
            state_out[127 - 32*i - 16 -: 8] = gmul_0d(s0) ^ gmul_09(s1) ^ gmul_0e(s2) ^ gmul_0b(s3);
            state_out[127 - 32*i - 24 -: 8] = gmul_0b(s0) ^ gmul_0d(s1) ^ gmul_09(s2) ^ gmul_0e(s3);
        end
    end

endmodule