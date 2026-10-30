# Semana 2 — Desafio: SubBytes e ShiftRows

## Módulos entregues
| Arquivo | Descrição |
|---|---|
| `rtl/minisoc_aes_sbox.sv` | S-box 8→8, combinacional (tabela FIPS-197, Fig. 7) |
| `rtl/minisoc_aes_sub_bytes.sv` | 16 instâncias da S-box sobre o estado de 128 bits |
| `rtl/minisoc_aes_shift_rows.sv` | Só reordenação de fios: `s'[r][c] = s[r][(c+r) mod 4]` |
| `rtl/minisoc_aes_inv_sbox.sv`, `inv_sub_bytes.sv`, `inv_shift_rows.sv` | Opcionais (inversas) |
| `tb/tb_minisoc_aes_sub_shift.sv` | Testbench autoverificável |

Convenção: byte `n` em `[127-8n -: 8]` (byte 0 = `[127:120]`), `r = n mod 4`, `c = n div 4`.

## Como rodar
```
./sim/run.sh     # lint (Verilator -Wall) + simulação (Icarus); termina com PASS
```

## Resultados
- S-box: 256/256 entradas conferidas contra referência calculada no testbench (inversa em GF(2^8) + afim), além de `sbox(00)=63` e `sbox(53)=ed`.
- SubBytes e ShiftRows: rodadas 1 a 10 do Apêndice B (Start of Round → After SubBytes → After ShiftRows), todas PASS.
- Opcional: `InvSubBytes(SubBytes(x)) = x` e `InvShiftRows(ShiftRows(x)) = x` em todas as rodadas e `inv_sbox(sbox(x)) = x` nas 256 entradas, PASS.
- Linguagem: SystemVerilog (IEEE 1800-2012: `logic`, `always_comb`, `generate` com `genvar` no `for`). Lint Verilator `-Wall`: sem erros nem warnings.
- Vetores gerados por `gen.py` (AES-128 do Apêndice B; cifra final `3925841d02dc09fbdc118597196a0b32` conferida).

## Dúvidas sobre o Block Guide (seções 1 a 3 e 8)
<!-- Preencher após a leitura. Não deixei dúvidas inventadas aqui. -->
1. 
2. 
