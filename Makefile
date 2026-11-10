# ==========================================================
# Diretorios
# ==========================================================
RTL_DIR   = rtl
TB_DIR    = tb
SYNTH_DIR = syn
FM_DIR    = formal
UPF_DIR   = upf
LOG_DIR   = logs

# ==========================================================
# Arquivos RTL e pacotes (ordem estrita de dependencia)
# ==========================================================
PKG_FILES = 

RTL_FILES = \
    $(RTL_DIR)/minisoc_aes/minisoc_aes_dp/minisoc_aes_sbox.sv \
    $(RTL_DIR)/minisoc_aes/minisoc_aes_dp/minisoc_aes_sub_bytes.sv \
    $(RTL_DIR)/minisoc_aes/minisoc_aes_dp/minisoc_aes_shift_rows.sv \
    $(RTL_DIR)/minisoc_aes/minisoc_aes_dp/minisoc_aes_inv_sbox.sv \
    $(RTL_DIR)/minisoc_aes/minisoc_aes_dp/minisoc_aes_inv_sub_bytes.sv \
    $(RTL_DIR)/minisoc_aes/minisoc_aes_dp/minisoc_aes_inv_shift_rows.sv

# ==========================================================
# Testbench
# ==========================================================
TB_FILES = \
    $(TB_DIR)/tb_minisoc_aes_sub_shift.sv \
    $(TB_DIR)/tb_semana3.sv

TOP = tb_semana3

# ==========================================================
# Simulacao (Synopsys VCS)
# ==========================================================
TIMESCALE = 1ns/1ps
FSDB      = aes_sim.fsdb

# Opcoes em tempo de execucao (ex: make run SEED=7 TEST=meu_teste)
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
	@echo "    make compile         compila RTL + TB com o VCS (gera ./simv)"
	@echo "    make run             compila e simula no VCS (SEED=n TEST=nome UVM_VERB=UVM_HIGH)"
	@echo "    make regress         roda varias seeds no VCS (SEEDS='1 2 3 4 5')"
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
# Compilacao / Simulacao VCS
# ==========================================================
compile:
	@mkdir -p $(LOG_DIR)
	vcs $(VCS_FLAGS) -top $(TOP) $(PKG_FILES) $(RTL_FILES) $(TB_FILES) -l $(LOG_DIR)/compile.log

run: compile
	./simv $(RUN_ARGS) -l $(LOG_DIR)/sim.log

# Regressao com varias seeds no VCS
SEEDS ?= 1 2 3 4 5
regress: compile
	@for s in $(SEEDS); do \
		echo "==> seed $$s"; \
		./simv +ntb_random_seed=$$s +UVM_VERBOSITY=UVM_LOW -l $(LOG_DIR)/sim_seed$$s.log || exit 1; \
	done

wave:
	verdi -dbdir simv.daidir -ssf $(FSDB) &

# ==========================================================
# UPF: simulacao power-aware (VCS NLP)
# ==========================================================
$(UPF_FILE):
	@echo "==> [UPF] $(UPF_FILE) nao encontrado. Crie o arquivo e ajuste supplies/dominios."
	@exit 1

compile_upf: $(UPF_FILE)
	@mkdir -p $(LOG_DIR)
	vcs $(VCS_FLAGS) -lca -upf $(UPF_FILE) -Mdir=csrc_upf -o simv_upf \
		-top $(TOP) $(PKG_FILES) $(RTL_FILES) $(TB_FILES) -l $(LOG_DIR)/compile_upf.log

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
	rm -rf csrc csrc_upf simv simv_upf simv*.daidir *.daidir novas* AN.DB ucli.key \
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

.PHONY: help compile run regress wave compile_upf run_upf synth fm_gen formality \
        clean_sim clean_synth clean_fm clean_upf clean