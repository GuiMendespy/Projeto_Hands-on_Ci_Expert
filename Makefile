# ==========================================================
# Diretorios
# ==========================================================
RTL_DIR   = rtl
TB_DIR    = tb
SYNTH_DIR = syn
FM_DIR    = formal
UPF_DIR   = upf
LOG_DIR   = logs
 
# Pasta do datapath AES (transformacoes, key_exp e dp).
# Se key_exp/dp ficarem em outra pasta (ex.: rtl/minisoc_aes), ajuste so esta variavel.
AES_DP_DIR = $(RTL_DIR)/minisoc_aes
 
# ==========================================================
# Arquivos RTL e pacotes (ordem estrita de dependencia)
# ==========================================================
# Pacote com as funcoes de GF(2^8) (xtime, mul2..mul14): usado por
# mix_columns, inv_mix_columns e key_exp. Deve ser compilado primeiro.
PKG_FILES = \
    $(AES_DP_DIR)/minisoc_aes_gf_pkg.sv
 
RTL_FILES = \
    $(AES_DP_DIR)/minisoc_aes_sbox.sv \
    $(AES_DP_DIR)/minisoc_aes_inv_sbox.sv \
    $(AES_DP_DIR)/minisoc_aes_sub_bytes.sv \
    $(AES_DP_DIR)/minisoc_aes_inv_sub_bytes.sv \
    $(AES_DP_DIR)/minisoc_aes_shift_rows.sv \
    $(AES_DP_DIR)/minisoc_aes_inv_shift_rows.sv \
    $(AES_DP_DIR)/minisoc_aes_add_round_key.sv \
    $(AES_DP_DIR)/minisoc_aes_mix_columns.sv \
    $(AES_DP_DIR)/minisoc_aes_inv_mix_columns.sv \
    $(AES_DP_DIR)/minisoc_aes_key_exp.sv \
    $(AES_DP_DIR)/minisoc_aes_dp.sv
 
# ==========================================================
# Testbenches
# ==========================================================
# Os vetores da FIPS-197 ficam em $(TB_DIR)/vectors/aes_vectors.svh
# (incluido pelos TBs da Semana 4 via `include "vectors/aes_vectors.svh").
TB_FILES = \
    $(TB_DIR)/tb_minisoc_aes_sub_shift.sv \
    $(TB_DIR)/tb_semana3.sv \
    $(TB_DIR)/tb_aes_key_exp.sv \
    $(TB_DIR)/tb_aes_dp.sv
 
VEC_FILES = $(TB_DIR)/vectors/aes_vectors.svh
 
# Nomes exatos dos modulos (declarados dentro dos arquivos SystemVerilog)
TOP_SUB_SHIFT = tb_minisoc_aes_sub_shift
TOP_SEMANA3   = tb_semana_03
TOP_KEY_EXP   = tb_aes_key_exp
TOP_DP        = tb_aes_dp
 
# ==========================================================
# Simulacao (Synopsys VCS)
# ==========================================================
TIMESCALE = 1ns/1ps
FSDB      = aes_sim.fsdb
 
# Opcoes em tempo de execucao (ex: make run_semana3 SEED=7 TEST=meu_teste)
SEED      ?= 1
UVM_VERB  ?= UVM_MEDIUM
TEST      ?=
RUN_ARGS  = +ntb_random_seed=$(SEED) +UVM_VERBOSITY=$(UVM_VERB) $(if $(TEST),+UVM_TESTNAME=$(TEST))
 
VCS_FLAGS = -full64 \
            -sverilog \
            -timescale=$(TIMESCALE) \
            -debug_access+all \
            -kdb \
            -ntb_opts uvm \
            +incdir+$(TB_DIR) \
            +incdir+$(RTL_DIR)
 
# ==========================================================
# UPF (baixo consumo)
# ==========================================================
UPF_FILE = $(UPF_DIR)/minisoc_aes.upf
 
# ==========================================================
# Sintese (Design Compiler) / Formality
# ==========================================================
SYNTH_TCL = $(SYNTH_DIR)/synth.tcl
FM_TCL    = $(FM_DIR)/formality_fm.tcl
SVF_FILE  = default.svf
 
# ==========================================================
# Ajuda
# ==========================================================
help:
	@echo ""
	@echo "  Simulacao VCS"
	@echo "    make run_sub_shift   compila e simula o testbench de SubBytes/ShiftRows"
	@echo "    make run_semana3     compila e simula o testbench completo da Semana 3"
	@echo "    make run_key_exp     Semana 4: key expansion (11 round keys da FIPS-197)"
	@echo "    make run_dp          Semana 4: datapath AES-128, cifra e decifra"
	@echo "    make run_semana4     Semana 4: executa run_key_exp e run_dp em sequencia"
	@echo "    make run_all         executa TODOS os testes (sub_shift, semana3, semana4)"
	@echo "    make wave            abre o Verdi com o FSDB e o banco KDB"
	@echo ""
	@echo "  Sintese / Formal"
	@echo "    make synth           sintese logica no Design Compiler ($(SYNTH_TCL))"
	@echo "    make formality       equivalencia RTL x netlist no Formality"
	@echo "    make fm_gen          regera o TCL base do Formality"
	@echo ""
	@echo "  UPF (baixo consumo)"
	@echo "    make run_upf         simulacao power-aware (VCS NLP) com o UPF"
	@echo ""
	@echo "  Limpeza: clean_sim | clean_synth | clean_fm | clean_upf | clean"
	@echo ""
 
# ==========================================================
# Compilacao e Simulacao por Testbench
# ==========================================================
 
# 1. Executa o teste de SubBytes e ShiftRows
run_sub_shift:
	@mkdir -p $(LOG_DIR)
	vcs $(VCS_FLAGS) -top $(TOP_SUB_SHIFT) $(PKG_FILES) $(RTL_FILES) $(TB_FILES) -o simv_sub_shift -l $(LOG_DIR)/compile_sub_shift.log
	./simv_sub_shift $(RUN_ARGS) -l $(LOG_DIR)/sim_sub_shift.log
 
# 2. Executa o teste integrado da Semana 3
run_semana3:
	@mkdir -p $(LOG_DIR)
	vcs $(VCS_FLAGS) -top $(TOP_SEMANA3) $(PKG_FILES) $(RTL_FILES) $(TB_FILES) -o simv_semana3 -l $(LOG_DIR)/compile_semana3.log
	./simv_semana3 $(RUN_ARGS) -l $(LOG_DIR)/sim_semana3.log
 
# 3. Semana 4: key expansion (vetores FIPS-197 Apendices B e C.1)
run_key_exp: $(VEC_FILES)
	@mkdir -p $(LOG_DIR)
	vcs $(VCS_FLAGS) -top $(TOP_KEY_EXP) $(PKG_FILES) $(RTL_FILES) $(TB_FILES) -o simv_key_exp -l $(LOG_DIR)/compile_key_exp.log
	./simv_key_exp $(RUN_ARGS) -l $(LOG_DIR)/sim_key_exp.log
	@grep -q "^PASS" $(LOG_DIR)/sim_key_exp.log || { echo "==> [FALHA] tb_aes_key_exp"; exit 1; }
 
# 4. Semana 4: datapath (C.1, B, 64 vetores aleatorios; cifra e decifra)
run_dp: $(VEC_FILES)
	@mkdir -p $(LOG_DIR)
	vcs $(VCS_FLAGS) -top $(TOP_DP) $(PKG_FILES) $(RTL_FILES) $(TB_FILES) -o simv_dp -l $(LOG_DIR)/compile_dp.log
	./simv_dp $(RUN_ARGS) -l $(LOG_DIR)/sim_dp.log
	@grep -q "^PASS" $(LOG_DIR)/sim_dp.log || { echo "==> [FALHA] tb_aes_dp"; exit 1; }
 
# 5. Comando da Semana 4: key_exp + dp
run_semana4: run_key_exp run_dp
	@echo "==> [Semana 4] key_exp e dp: PASS"
 
# 6. Executa todos os testes em sequencia
run_all: run_sub_shift run_semana3 run_semana4
 
# Atalho padrao para rodar todos os testes
run: run_all
 
# Regressao com varias seeds no teste da Semana 3
SEEDS ?= 1 2 3 4 5
regress:
	@mkdir -p $(LOG_DIR)
	vcs $(VCS_FLAGS) -top $(TOP_SEMANA3) $(PKG_FILES) $(RTL_FILES) $(TB_FILES) -o simv_semana3 -l $(LOG_DIR)/compile_semana3.log
	@for s in $(SEEDS); do \
		echo "==> seed $$s"; \
		./simv_semana3 +ntb_random_seed=$$s +UVM_VERBOSITY=UVM_LOW -l $(LOG_DIR)/sim_seed$$s.log || exit 1; \
	done
 
wave:
	verdi -dbdir simv_semana3.daidir -ssf $(FSDB) &
 
# ==========================================================
# UPF: simulacao power-aware (VCS NLP)
# ==========================================================
$(UPF_FILE):
	@echo "==> [UPF] $(UPF_FILE) nao encontrado. Crie o arquivo e ajuste supplies/dominios."
	@exit 1
 
compile_upf: $(UPF_FILE)
	@mkdir -p $(LOG_DIR)
	vcs $(VCS_FLAGS) -lca -upf $(UPF_FILE) -Mdir=csrc_upf -o simv_upf \
		-top $(TOP_SEMANA3) $(PKG_FILES) $(RTL_FILES) $(TB_FILES) -l $(LOG_DIR)/compile_upf.log
 
run_upf: compile_upf
	./simv_upf $(RUN_ARGS) -l $(LOG_DIR)/sim_upf.log
 
# ==========================================================
# Sintese logica (Design Compiler)
# ==========================================================
synth:
	@mkdir -p $(SYNTH_DIR)/reports $(LOG_DIR)
	setarch `uname -m` -R dc_shell -f $(SYNTH_TCL) | tee $(LOG_DIR)/synth.log
 
# ==========================================================
# Formality
# ==========================================================
$(FM_TCL):
	@echo "==> [Formality] $(FM_TCL) nao encontrado. Gerando esqueleto inicial..."
	@mkdir -p $(FM_DIR)
	fm_mk_script -output $(FM_TCL) $(SVF_FILE)
 
fm_gen:
	@echo "==> [Formality] Regerando o script TCL base..."
	@mkdir -p $(FM_DIR)
	fm_mk_script -output $(FM_TCL) $(SVF_FILE)
 
formality: $(FM_TCL)
	@echo "==> [Formality] Verificacao de equivalencia..."
	cd $(FM_DIR) && fm_shell -f formality_fm.tcl | tee formality_run.log
 
# ==========================================================
# Limpeza
# ==========================================================
clean_sim:
	rm -rf csrc csrc_upf simv* simv*.daidir *.daidir novas* AN.DB ucli.key \
		verdi* DVEfiles .vlogan* *.fsdb *.vcd command.log filename.log $(LOG_DIR)
 
clean_synth:
	rm -rf work $(SYNTH_DIR)/work $(SYNTH_DIR)/reports/*.rpt $(SYNTH_DIR)/*.rpt \
		$(SYNTH_DIR)/*.ddc $(SYNTH_DIR)/*.db $(SYNTH_DIR)/*_syn.v \
		Synopsys_stack_trace* crte_* default.svf
 
clean_fm:
	rm -rf $(FM_DIR)/*.log $(FM_DIR)/FM_WORK* $(FM_DIR)/reports $(FM_DIR)/formality_svf FM_WORK*
 
clean_upf:
	rm -rf csrc_upf simv_upf simv_upf.daidir
 
clean: clean_sim clean_synth clean_fm clean_upf
 
.PHONY: help run_sub_shift run_semana3 run_key_exp run_dp run_semana4 run_all run regress wave \
        compile_upf run_upf synth fm_gen formality clean_sim clean_synth clean_fm clean_upf clean

