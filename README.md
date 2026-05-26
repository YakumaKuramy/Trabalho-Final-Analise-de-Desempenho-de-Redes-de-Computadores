# Análise de Desempenho de Protocolos de Transporte (TCP vs UDP) em Redes com Perda de Pacotes

Este repositório contém o planejamento, os scripts de automação e a análise estatística para o trabalho final da disciplina de **Análise de Desempenho de Redes de Computadores**. O foco deste projeto é avaliar quantitativamente o impacto do descarte de pacotes na eficiência das conexões de rede utilizando emulação.

---

## 📊 Planejamento do Experimento (Abordagem Sistemática)

Este planejamento segue as diretrizes metodológicas para a avaliação de desempenho de sistemas computacionais, delimitando o escopo do experimento para a avaliação de conformidade da banca.

### 1. Domínio (Sistema sob Estudo)

O sistema sob avaliação compreende o subsistema de comunicação de dados na camada de transporte da pilha TCP/IP, operando em um ambiente híbrido. O ambiente de testes é composto por um cliente gerador de tráfego local executado em ambiente emulado (**WSL2/Ubuntu**) e um servidor receptor hospedado em infraestrutura de nuvem (**AWS EC2/Ubuntu**).

O escopo do estudo concentra-se nos mecanismos de entrega de dados e retransmissão sob condições adversas induzidas na interface de rede.

### 2. Objetivos

O objetivo deste trabalho é quantificar e comparar o impacto de diferentes taxas de perda de pacotes na eficiência da transmissão de dados utilizando os protocolos TCP e UDP.

**Hipótese de Desempenho:** O mecanismo de controle de congestionamento e retransmissão baseado em janelas do TCP causará uma degradação de performance (vazão útil) exponencial e desproporcional em redes instáveis. Em contrapartida, o UDP apresentará um comportamento estritamente linear, mantendo o fluxo contínuo de envio na origem independente do descarte no destino.

### 3. Métricas de Desempenho

Para avaliar o comportamento do sistema e responder aos objetivos propostos, foram selecionadas as seguintes métricas de saída (variáveis dependentes):

- **Throughput (Vazão Bruta):** Taxa total de bits transmitidos por unidade de tempo na camada de transporte, mensurada na origem (Sender). Unidade: Megabits por segundo (Mbps).
- **Goodput (Vazão Útil):** Taxa de bits de dados úteis (payload da aplicação) efetivamente recebidos, processados e entregues à camada de aplicação no destino (Receiver). Unidade: Megabits por segundo (Mbps).
- **Taxa de Perda Efetiva (Packet Loss):** Percentual real de pacotes descartados durante a transmissão em relação ao total enviado, utilizada como métrica de validação do emulador de rede. Unidade: Percentual (%).

### 4. Fatores e Níveis

O experimento foi projetado para isolar as variáveis de interesse através da seguinte configuração de fatores, níveis e parâmetros constantes:

#### Fatores (Variáveis Independentes)

- **Protocolo de Transporte (Fator Qualitativo):** 2 Níveis (`TCP` e `UDP`).
- **Taxa de Perda de Pacotes Emulada (Fator Quantitativo):** 6 Níveis (`0%`, `1%`, `3%`, `5%`, `10%`, e `20%`).

#### Parâmetros Mantidos Constantes (Carga e Ambiente)

- **Duração do Intervalo de Teste:** 30 segundos por execução.
- **Largura de Banda Alvo (Carga UDP):** Limitada explicitamente em 100 Mbps para evitar a saturação irrealista do canal de uplink doméstico.
- **Algoritmo de Controle de Congestionamento TCP:** Padrão do Kernel Linux (`Cubic`).
- **Tamanho do Bloco de Leitura/Escrita (Buffer):** Padrão do utilitário de medição.
- **Ferramenta de Emulação:** `tc` com o módulo `netem` (Network Emulator) aplicado na interface de rede de saída do cliente.
- **Ferramenta de Geração de Tráfego:** `iPerf3`.

---

## 🛠️ Tecnologias e Ferramentas Mapeadas

Para a execução física do experimento planejado acima, o projeto fará uso do seguinte conjunto tecnológico:

- **Ambientes:** Windows Subsystem for Linux (WSL2 / Ubuntu 22.04 LTS) e AWS EC2 (Instância t2.micro / Ubuntu Server).
- **Emulação e Injeção de Falhas:** Utilitário `tc` (_Traffic Control_) integrado ao kernel Linux através do módulo `netem`.
- **Geração de Carga e Medição:** Ferramenta de diagnóstico de rede `iPerf3` (operando em arquitetura Cliente-Servidor).
- **Análise Estatística e Gráficos:** Linguagem **R** (ambiente RStudio) para importação dos dados capturados, cálculo de médias, intervalos de confiança e plotagem das curvas de desempenho.
