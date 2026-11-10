# Relatório de Entregas — Semana 03
**Projeto Integrador MiniSoC AES**  
**Residência em Microeletrônica — Polo UFCG**  
**Data:** 06/11/2026  
**Documento:** `docs/reports/semana_03.md`

---

## 1. Visão Geral

A Semana 03 teve como foco a especificação da microarquitetura interna do engine AES (`minisoc_aes_top`), o projeto das transformações de rodada diretas e inversas do padrão NIST FIPS-197, o estabelecimento do mecanismo de *Clock Domain Crossing* (CDC) via *toggle*, e a definição da estratégia de reset síncrono atrelado ao travamento da PLL mock.

---

## 2. Resumo da Microarquitetura

* **Datapath do AES:** Adotada a arquitetura **Iterativa de 128 bits** (1 rodada por ciclo de clock). Oferece o melhor compromisso entre consumo de área em silício e desempenho (~10 ciclos por bloco de 128 bits).
* **FSM do Controlador (`minisoc_aes_top`):**
  * `IDLE`: Aguarda pulso `cmd_start`.
  * `VAL_CONFIG`: Valida se $1 \le \text{NUM\_BLOCKS} \le 256$ e se o modo de operação é válido.
  * `KEY_EXP`: Dispara a expansão da chave AES-128.
  * `FETCH_W0..W3`: Lê 4 palavras sequenciais de 32 bits ($1024 \times 32$ SRAM) para montar o bloco de 128 bits.
  * `EXEC_BLOCK`: Executa as 10 rodadas da cifra/decifra no datapath.
  * `WRITE_W0..W3`: Escreve o resultado de 128 bits *in-place* na mesma região de memória.
  * `UPDATE_BLOCK`: Incrementa o contador `BLOCKS_DONE` e avança os endereços base.
  * `DONE`: Indica a conclusão (*sticky flag*).
* **Clock Domain Crossing (CDC):**
  * Sincronização por **Toggle** do sinal de quadro concluído (`frame_done`) do domínio do SPI (`spi_sclk` $\le 25\text{ MHz}$) para o domínio de controle (`clk` a $2\text{ GHz}$).
  * Utilização de sincronizador de 2 estágios de flip-flops (*2-FF Synchronizer*) e detector de borda por porta XOR.
* **Sincronização de Reset:**
  * O reset global `rst_n` inicializa o domínio de controle.
  * O reset do domínio do sistema (`sys_rst_n`) utiliza a topologia *Async Assert, Sync Deassert* (*Reset Synchronizer Bridge*), sendo liberado somente após a PLL sinalizar travamento (`SYSTEM_STATUS.PLL_LOCKED = 1`).

---

## 3. Módulos RTL Implementados (`rtl/minisoc_aes/`)

| Módulo | Tipo | Descrição |
| :--- | :--- | :--- |
| `minisoc_aes_add_round_key.sv` | Combinacional | Operação XOR de 128 bits entre o *State* e a *Round Key*. |
| `minisoc_aes_sub_bytes.sv` | Combinacional | Substituição S-Box paralela de 16 bytes. |
| `minisoc_aes_shift_rows.sv` | Permutação | Rotação cíclica das linhas da matriz $4 \times 4$ do *State*. |
| `minisoc_aes_mix_columns.sv` | Combinacional | Multiplicação matricial em $GF(2^8)$ com polinômio $m(x) = x^8 + x^4 + x^3 + x + 1$. |
| `minisoc_aes_inv_sub_bytes.sv` | Combinacional | Substituição inversa por tabela RS-Box de 16 bytes. |
| `minisoc_aes_inv_shift_rows.sv` | Permutação | Rotação cíclica inversa das linhas da matriz $4 \times 4$. |
| `minisoc_aes_inv_mix_columns.sv` | Combinacional | Multiplicação por $\{0e\}, \{0b\}, \{0d\}, \{09\}$ em $GF(2^8)$. |

---

## 4. Estrutura do Repositório (Entregáveis da Semana 3)

```text
├── docs/
│   ├── architecture/
│   │   └── microarchitecture_v1.0.tex   # Documento de Especificação (LaTeX / Overleaf)
│   └── reports/
│       └── semana_03.md                 # Este relatório de resumo
├── rtl/
│   └── minisoc_aes/
│       ├── minisoc_aes_add_round_key.sv
│       ├── minisoc_aes_sub_bytes.sv
│       ├── minisoc_aes_shift_rows.sv
│       ├── minisoc_aes_mix_columns.sv
│       ├── minisoc_aes_inv_sub_bytes.sv
│       ├── minisoc_aes_inv_shift_rows.sv
│       └── minisoc_aes_inv_mix_columns.sv
└── tb/
    └── tb_semana_03.sv                  # Testbench autoverificável
```

---

## 5. Verificação e Critérios de Aceite

### 5.1 Vetores Intermediários da FIPS-197 (Apêndice B)
* **Entrada (`start of round`):** `193de3bea0f4e22b9ac68d2ae9f84808`
* **Resultado `SubBytes`:** `d42711aee0bf98f1b8b45de51e415230` $\rightarrow$ **PASS**
* **Resultado `ShiftRows`:** `d4bf5d30e0b452aeb84111f11e2798e5` $\rightarrow$ **PASS**

### 5.2 Teste Sanidade das Inversas
Foram testadas e aprovadas as propriedades de identidade bijetora:
$$\text{InvSubBytes}(\text{SubBytes}(x)) = x \quad \text{--- PASS}$$
$$\text{InvShiftRows}(\text{ShiftRows}(x)) = x \quad \text{--- PASS}$$
$$\text{InvMixColumns}(\text{MixColumns}(x)) = x \quad \text{--- PASS}$$

### 5.3 Análise Linter
Executado linter estático sem ocorrência de erros ou *warnings*:
```bash
verilator --lint-only -Wall -Irtl/minisoc_aes rtl/minisoc_aes/*.sv
```

---

## 6. Como Executar a Simulação

Para rodar o testbench autoverificável da Semana 03 com um único comando:

```bash
# Execução via Icarus Verilog / Verilator
make test_semana_03
```

**Resultado esperado:**
```text
[TB_SEMANA_03] Verificando SubBytes (Apêndice B)... PASS
[TB_SEMANA_03] Verificando ShiftRows (Apêndice B)... PASS
[TB_SEMANA_03] Verificando InvShiftRows... PASS
[TB_SEMANA_03] Verificando InvSubBytes... PASS
[TB_SEMANA_03] Verificando InvMixColumns(MixColumns(X))... PASS
=====================================================
SEMANA 3: TODOS OS TESTES PASSARAM COM SUCESSO!
=====================================================
```