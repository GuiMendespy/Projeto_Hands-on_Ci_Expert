`timescale 1ns/1ps

module minisoc_aes_dp (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [127:0] i_key,
    input  logic         i_key_load,
    output logic         o_key_ready,
    input  logic         i_start,
    input  logic         i_decrypt,
    input  logic [127:0] i_block,
    output logic [127:0] o_block,
    output logic         o_busy,
    output logic         o_done
);

    // -------------------------------------------------------------------------
    // Registradores e Sinais Internos
    // -------------------------------------------------------------------------
    logic [127:0] state;
    logic [127:0] block_reg;
    logic [3:0]   round_cnt;
    logic         busy;
    logic         done;
    logic         decrypt_reg;

    // Sinais intermediários da Cifragem (Encrypt)
    logic [127:0] e_sb, e_sr, e_mc;
    
    // Sinais intermediários da Decifragem (Decrypt)
    logic [127:0] d_isr, d_isb, d_imc;

    // Sinais do AddRoundKey
    logic [127:0] ark_in, ark_out;

    // Sinais de controle de Round Key
    logic [127:0] rk;
    logic [3:0]   rk_sel;
    logic         key_exp_ready;

    assign o_busy      = busy;
    assign o_done      = done;
    assign o_block     = block_reg;
    assign o_key_ready = key_exp_ready;

    // -------------------------------------------------------------------------
    // Instanciação do Key Expansion
    // -------------------------------------------------------------------------
    minisoc_aes_key_exp u_key_exp (
        .clk      (clk),
        .rst_n    (rst_n),
        .i_start  (i_key_load),
        .i_key    (i_key),
        .o_busy   (),
        .o_ready  (key_exp_ready),
        .i_rk_sel (rk_sel),
        .o_rk     (rk)
    );

    // -------------------------------------------------------------------------
    // Instanciação dos Blocos de Transformação
    // -------------------------------------------------------------------------
    
    // SubBytes: .i_state / .o_state
    minisoc_aes_sub_bytes u_sb (
        .i_state   (state),
        .o_state   (e_sb)
    );

    // ShiftRows: .entrada / .saida
    minisoc_aes_shift_rows u_sr (
        .entrada   (e_sb),
        .saida     (e_sr)
    );

    // MixColumns: .state_in / .state_out
    minisoc_aes_mix_columns u_mc (
        .state_in  (e_sr),
        .state_out (e_mc)
    );

    // InvShiftRows: .entrada / .saida
    minisoc_aes_inv_shift_rows u_isr (
        .entrada   (state),
        .saida     (d_isr)
    );

    // InvSubBytes: .entrada / .saida
    minisoc_aes_inv_sub_bytes u_isb (
        .entrada   (d_isr),
        .saida     (d_isb)
    );

    // AddRoundKey: .state_in / .round_key / .state_out
    minisoc_aes_add_round_key u_ark (
        .state_in  (ark_in),
        .round_key (rk),
        .state_out (ark_out)
    );

    // InvMixColumns: na decifragem, é aplicada APÓS o AddRoundKey (ark_out)
    minisoc_aes_inv_mix_columns u_imc (
        .state_in  (ark_out),
        .state_out (d_imc)
    );

    // -------------------------------------------------------------------------
    // Seleção de Round Key e Multiplexação de Entrada do AddRoundKey
    // -------------------------------------------------------------------------
    always_comb begin
        if (!decrypt_reg) begin
            rk_sel = round_cnt;
        end else begin
            rk_sel = 4'd10 - round_cnt;
        end
    end

    always_comb begin
        if (!decrypt_reg) begin
            if (round_cnt == 4'd0)       ark_in = state;
            else if (round_cnt == 4'd10) ark_in = e_sr;
            else                         ark_in = e_mc;
        end else begin
            if (round_cnt == 4'd0)       ark_in = state;
            else                         ark_in = d_isb;
        end
    end

    // -------------------------------------------------------------------------
    // FSM de Controle de Rodadas (10 rodadas)
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE,
        INIT_ROUND,
        ROUNDS,
        FINAL_ROUND
    } state_e;

    state_e current_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            round_cnt     <= 4'd0;
            state         <= 128'h0;
            block_reg     <= 128'h0;
            busy          <= 1'b0;
            done          <= 1'b0;
            decrypt_reg   <= 1'b0;
        end else begin
            done <= 1'b0;
            
            case (current_state)
                IDLE: begin
                    if (i_start && key_exp_ready) begin
                        busy          <= 1'b1;
                        decrypt_reg   <= i_decrypt;
                        state         <= i_block;
                        round_cnt     <= 4'd0;
                        current_state <= INIT_ROUND;
                    end
                end

                INIT_ROUND: begin
                    // Rodada 0: AddRoundKey inicial
                    state         <= ark_out;
                    round_cnt     <= 4'd1;
                    current_state <= ROUNDS;
                end

                ROUNDS: begin
                    if (round_cnt < 4'd10) begin
                        if (decrypt_reg) begin
                            // Na decifragem (rodadas 1..9), InvMixColumns atua sobre a saída de AddRoundKey
                            state <= d_imc;
                        end else begin
                            state <= ark_out;
                        end
                        round_cnt <= round_cnt + 1'b1;
                    end else begin
                        // Rodada 10: Sem InvMixColumns
                        state         <= ark_out;
                        current_state <= FINAL_ROUND;
                    end
                end

                FINAL_ROUND: begin
                    block_reg     <= state;
                    busy          <= 1'b0;
                    done          <= 1'b1;
                    current_state <= IDLE;
                end
            endcase
        end
    end

endmodule