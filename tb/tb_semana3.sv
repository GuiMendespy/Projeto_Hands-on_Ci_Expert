`timescale 1ns/1ps

module tb_semana_03;

    // -------------------------------------------------------------------------
    // Sinais de Interface e Instanciação dos Módulos
    // -------------------------------------------------------------------------
    logic [127:0] state_in;
    logic [127:0] round_key;

    // Saídas Diretas
    logic [127:0] out_add_round_key;
    logic [127:0] out_sub_bytes;
    logic [127:0] out_shift_rows;
    logic [127:0] out_mix_columns;

    // Saídas Inversas
    logic [127:0] out_inv_sub_bytes;
    logic [127:0] out_inv_shift_rows;
    logic [127:0] out_inv_mix_columns;

    // Contadores de Teste
    int total_tests  = 0;
    int passed_tests = 0;
    int failed_tests = 0;

    // Instanciação dos Módulos Sob Teste (DUTs)
    minisoc_aes_add_round_key u_add_rk (
        .state_in(state_in),
        .round_key(round_key),
        .state_out(out_add_round_key)
    );

    minisoc_aes_sub_bytes u_sb (
        .state_in(state_in),
        .state_out(out_sub_bytes)
    );

    minisoc_aes_shift_rows u_sr (
        .state_in(state_in),
        .state_out(out_shift_rows)
    );

    minisoc_aes_mix_columns u_mc (
        .state_in(state_in),
        .state_out(out_mix_columns)
    );

    minisoc_aes_inv_sub_bytes u_isb (
        .state_in(state_in),
        .state_out(out_inv_sub_bytes)
    );

    minisoc_aes_inv_shift_rows u_isr (
        .state_in(state_in),
        .state_out(out_inv_shift_rows)
    );

    minisoc_aes_inv_mix_columns u_imc (
        .state_in(state_in),
        .state_out(out_inv_mix_columns)
    );

    // -------------------------------------------------------------------------
    // Tasks Helper para Formatação de Log no Terminal
    // -------------------------------------------------------------------------
    task automatic log_section(input string title);
        $display("\n================================================================================");
        $display("  %s", title);
        $display("================================================================================");
    endtask

    task automatic check_128b(
        input string name,
        input logic [127:0] obtained,
        input logic [127:0] expected
    );
        total_tests++;
        if (obtained === expected) begin
            passed_tests++;
            $display("  [PASS] Teste %02d | %-28s", total_tests, name);
            $display("         Obtido:   0x%h", obtained);
        end else begin
            failed_tests++;
            $display("  [FAIL] Teste %02d | %-28s", total_tests, name);
            $display("         Obtido:   0x%h", obtained);
            $display("         Esperado: 0x%h", expected);
        end
    endtask

    // -------------------------------------------------------------------------
    // Sequência Principal de Testes
    // -------------------------------------------------------------------------
    initial begin
        log_section("MINISOC AES - TESTBENCH DE VALIDAÇÃO DA SEMANA 3");
        $display("  Iniciando suíte de testes unitários para transformações de rodada...");

        // =====================================================================
        // GRUPO 1: Transformações Diretas - Vetores FIPS-197 Apêndice B (Rodada 1)
        // =====================================================================
        log_section("GRUPO 1: Cifragem Direta (FIPS-197 Apêndice B)");

        // 1.1 AddRoundKey (Rodada 0)
        state_in  = 128'h3243f6a8885a308d313198a2e0370734; // Plaintext
        round_key = 128'h2b7e151628aed2a6abf7158809cf4f3c; // Key 0
        #10;
        check_128b("AddRoundKey (R0 / Start)", out_add_round_key, 128'h193de3bea0f4e22b9ac68d2ae9f84808);

        // 1.2 SubBytes (Rodada 1)
        state_in  = 128'h193de3bea0f4e22b9ac68d2ae9f84808;
        #10;
        check_128b("SubBytes (R1)", out_sub_bytes, 128'hd42711aee0bf98f1b8b45de51e415230);

        // 1.3 ShiftRows (Rodada 1)
        state_in  = 128'hd42711aee0bf98f1b8b45de51e415230;
        #10;
        check_128b("ShiftRows (R1)", out_shift_rows, 128'hd4bf5d30e0b452aeb84111f11e2798e5);

        // 1.4 MixColumns (Rodada 1)
        state_in  = 128'hd4bf5d30e0b452aeb84111f11e2798e5;
        #10;
        check_128b("MixColumns (R1)", out_mix_columns, 128'h046681e5e0cb199a48f8d37a2806264c);

        // 1.5 AddRoundKey (Rodada 1)
        state_in  = 128'h046681e5e0cb199a48f8d37a2806264c;
        round_key = 128'ha0fafe1788542cb123a339392a6c7605; // Round Key 1
        #10;
        check_128b("AddRoundKey (R1 Output)", out_add_round_key, 128'ha49c7ff2689f352b6b5be043026a5049);


        // =====================================================================
        // GRUPO 2: Transformações Inversas - Vetores de Referência
        // =====================================================================
        log_section("GRUPO 2: Decriptação Inversa");

        // 2.1 InvMixColumns (Inverso de MixColumns R1)
        state_in  = 128'h046681e5e0cb199a48f8d37a2806264c;
        #10;
        check_128b("InvMixColumns", out_inv_mix_columns, 128'hd4bf5d30e0b452aeb84111f11e2798e5);

        // 2.2 InvShiftRows (Inverso de ShiftRows R1)
        state_in  = 128'hd4bf5d30e0b452aeb84111f11e2798e5;
        #10;
        check_128b("InvShiftRows", out_inv_shift_rows, 128'hd42711aee0bf98f1b8b45de51e415230);

        // 2.3 InvSubBytes (Inverso de SubBytes R1)
        state_in  = 128'hd42711aee0bf98f1b8b45de51e415230;
        #10;
        check_128b("InvSubBytes", out_inv_sub_bytes, 128'h193de3bea0f4e22b9ac68d2ae9f84808);


        // =====================================================================
        // GRUPO 3: Sanity Check - Propriedade da Identidade Inversa f^-1(f(x)) = x
        // =====================================================================
        log_section("GRUPO 3: Verificação da Propriedade Inversa f^-1(f(x)) = x");

        // 3.1 InvShiftRows(ShiftRows(X)) == X
        state_in = 128'hA5A55A5A123456789ABCDEF0FEEDBEEF;
        #10;
        state_in = out_shift_rows;
        #10;
        check_128b("InvShiftRows(ShiftRows(X))", out_inv_shift_rows, 128'hA5A55A5A123456789ABCDEF0FEEDBEEF);

        // 3.2 InvSubBytes(SubBytes(X)) == X
        state_in = 128'h00112233445566778899AABBCCDDEEFF;
        #10;
        state_in = out_sub_bytes;
        #10;
        check_128b("InvSubBytes(SubBytes(X))", out_inv_sub_bytes, 128'h00112233445566778899AABBCCDDEEFF);

        // 3.3 InvMixColumns(MixColumns(X)) == X
        state_in = 128'hFEDCBA98765432100123456789ABCDEF;
        #10;
        state_in = out_mix_columns;
        #10;
        check_128b("InvMixColumns(MixColumns(X))", out_inv_mix_columns, 128'hFEDCBA98765432100123456789ABCDEF);


        // =====================================================================
        // RELATÓRIO FINAL DE EXECUÇÃO
        // =====================================================================
        log_section("RESUMO DO TESTE DA SEMANA 3");
        $display("  Total de testes executados : %0d", total_tests);
        $display("  Testes com SUCESSO (PASS)  : %0d", passed_tests);
        $display("  Testes com FALHA   (FAIL)  : %0d", failed_tests);
        $display("--------------------------------------------------------------------------------");

        if (failed_tests == 0) begin
            $display("  RESULTADO FINAL: [ PASS ] - TODAS AS TRANSFORMAÇÕES ESTÃO CORRETAS!\n");
        end else begin
            $display("  RESULTADO FINAL: [ FAIL ] - EXISTEM FALHAS NAS TRANSFORMAÇÕES DE RODADA.\n");
            $stop;
        end

        $finish;
    end

endmodule