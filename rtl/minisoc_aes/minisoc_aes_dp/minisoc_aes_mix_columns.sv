module minisoc_aes_mix_columns (
    input  logic [127:0] state_in,
    output logic [127:0] state_out
);
    // Multiplicação por {02} em GF(2^8)
    function automatic logic [7:0] xtime(input logic [7:0] b);
        return (b[7]) ? ((b << 1) ^ 8'h1b) : (b << 1);
    endfunction

    // Multiplicação por {03} = xtime(b) XOR b
    function automatic logic [7:0] mul_03(input logic [7:0] b);
        return xtime(b) ^ b;
    endfunction

    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_col
            logic [7:0] s0, s1, s2, s3;
            assign s0 = state_in[127 - 32*i : 120 - 32*i];
            assign s1 = state_in[119 - 32*i : 112 - 32*i];
            assign s2 = state_in[111 - 32*i : 104 - 32*i];
            assign s3 = state_in[103 - 32*i : 96  - 32*i];

            assign state_out[127 - 32*i : 120 - 32*i] = xtime(s0) ^ mul_03(s1) ^ s2 ^ s3;
            assign state_out[119 - 32*i : 112 - 32*i] = s0 ^ xtime(s1) ^ mul_03(s2) ^ s3;
            assign state_out[111 - 32*i : 104 - 32*i] = s0 ^ s1 ^ xtime(s2) ^ mul_03(s3);
            assign state_out[103 - 32*i : 96  - 32*i] = mul_03(s0) ^ s1 ^ s2 ^ xtime(s3);
        end
    endgenerate
endmodule