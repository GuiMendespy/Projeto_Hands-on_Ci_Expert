# 🚀 Projeto Hands-on CI Expert — Semana 1

Este repositório contém a estrutura inicial, automações de ambiente e os estudos desenvolvidos durante a **Semana 1** do projeto **Hands-on CI Expert**.

---

## 📌 Visão Geral da Semana 1

A primeira semana do projeto é dedicada ao kick-off, organização do fluxo de trabalho no GitHub, configuração do ambiente de simulação/lint e estudo teórico dos pilares do projeto: o algoritmo **AES (FIPS-197)** e o protocolo **SPI**.

### 🎯 Atividades Realizadas

1. **Apresentação e Especificação Funcional:** Análise e alinhamento do escopo do projeto.
2. **Estudo Teórico:**
   - **Algoritmo AES (FIPS-197):** Estrutura de blocos, rodadas (*rounds*), funções *SubBytes*, *ShiftRows*, *MixColumns* e *AddRoundKey*.
   - **Protocolo SPI:** Modos de operação (0, 1, 2, 3), polaridade ($CPOL$) e fase de clock ($CPHA$).
3. **Arquitetura do Sistema:** Compreensão da estrutura do *AES Top-Level System* para as trilhas de RTL e Verificação.
4. **Ambiente de Desenvolvimento:** Estruturação do repositório Git, criação do `Makefile` para automação e configuração das ferramentas de *lint* e simulação.
5. **Backlog Inicial:** Mapeamento e planejamento das tarefas do projeto.

---

## 📁 Estrutura do Repositório

```text
Projeto_Hands-on_Ci_Expert/
├── .gitignore           # Arquivos temporários e de compilação ignorados pelo Git
├── Makefile             # Script de automação do fluxo (compilação, lint e simulação)
├── README.md            # Documentação principal do projeto
├── rtl/                 # Módulos em SystemVerilog (Design RTL)
├── tb/                  # Testbench e arquivos do ambiente de verificação
└── docs/                # Relatórios e especificações do projeto
|__formal/               # Alálise do formality
|__syn/                  # Scripts de sintese
|__upf                   # Análise de Low Power