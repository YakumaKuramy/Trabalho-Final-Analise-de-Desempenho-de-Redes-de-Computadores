# Analise de Desempenho de Protocolos de Transporte: TCP CUBIC vs UDP em Redes com Perda de Pacotes

Este repositório contém o ambiente automatizado, os scripts de coleta, os mecanismos de processamento estatístico e os resultados de um experimento sistemático projetado para analisar o impacto da perda de pacotes emulada no Throughput (vazão bruta) e Goodput (vazão útil) dos protocolos TCP (Cubic) e UDP.

O experimento consiste em 360 testes automatizados divididos em 30 réplicas estatísticas para cada cenário de perda planejado (0%, 1%, 3%, 5%, 10% e 20%). A arquitetura utiliza uma topologia cliente-servidor distribuída entre o ambiente local (WSL2) e a nuvem (AWS).

## 1. Dimensionamento de Tempo e Restrições da AWS

O tempo total estimado para a execução de toda a bateria de testes automatizados é de aproximadamente 180 minutos (3 horas), considerando que cada uma das 360 réplicas possui uma janela de transmissão ativa de 30 segundos, somada aos intervalos de execução, limpeza de buffers e reconfiguração das tabelas de roteamento do kernel.

A infraestrutura de laboratório utilizada na AWS (Learner Lab) possui uma restrição severa de tempo: cada sessão ativa de laboratório expira automaticamente após 180 minutos (3 horas). Como o tempo de execução do script consome o limite exato da sessão, qualquer oscilação ou atraso na rede resultará no encerramento da instância antes da conclusão da coleta.

### Estratégia de Divisão do Experimento

Para garantir a integridade dos dados e mitigar o risco de timeout da sessão da AWS, a execução deve ser obrigatoriamente segmentada em duas sessões distintas do laboratório:

- **Sessão 1 da AWS (Primeira Metade):** Execução exclusiva dos cenários de perda de 0%, 1% e 3%. Ao final desta sessão, os logs gerados devem ser salvos e compactados.
- **Sessão 2 da AWS (Segunda Metade):** Inicialização de uma nova sessão de laboratório, reinicialização das instâncias e execução dos cenários restantes de 5%, 10% e 20%.

---

## 2. Resultados Coletados e Consolidados

Os dados estatísticos processados a partir das 30 réplicas por cenário encontram-se estruturados no arquivo `resumo_estatistico_final.csv`:

| Protocolo | Taxa de Perda | Throughput Médio (Mbps) | Desvio Padrão T. | Goodput Médio (Mbps) | Desvio Padrão G. |
| --------- | ------------- | ----------------------- | ---------------- | -------------------- | ---------------- |
| TCP       | 0%            | 78.55                   | 26.11            | 77.68                | 26.58            |
| UDP       | 0%            | 100.00                  | 0.00             | 99.18                | 2.52             |
| TCP       | 1%            | 2.59                    | 0.67             | 2.29                 | 0.50             |
| UDP       | 1%            | 100.00                  | 0.00             | 98.64                | 0.07             |
| TCP       | 3%            | 1.05                    | 0.25             | 0.92                 | 0.18             |
| UDP       | 3%            | 93.33                   | 25.37            | 96.56                | 0.29             |
| TCP       | 5%            | 0.74                    | 0.15             | 0.67                 | 0.11             |
| UDP       | 5%            | 90.00                   | 30.51            | 90.24                | 7.36             |
| TCP       | 10%           | 0.40                    | 0.10             | 0.35                 | 0.06             |
| UDP       | 10%           | 90.00                   | 30.51            | 89.36                | 0.85             |
| TCP       | 20%           | 0.20                    | 0.02             | 0.17                 | 0.02             |
| UDP       | 20%           | 66.66                   | 47.94            | 79.39                | 0.58             |

---

## 3. Arquitetura e Pré-requisitos de Software

O ambiente operacional exige duas máquinas baseadas em Linux com conectividade direta através da internet:

### Servidor (Receptor) - Instância EC2 na AWS

- Sistema Operacional: Ubuntu Server 22.04 LTS ou superior.
- Configuração do Security Group: Liberação de tráfego de entrada na porta TCP e UDP 5201 para o IP público do cliente.
- Pacotes necessários: `iperf3`.

### Cliente (Emissor) - Ambiente Local (WSL2)

- Sistema Operacional: Ubuntu instalado sobre o subsistema WSL2 no Windows.
- Pacotes necessários: `iperf3`, `iproute2` (provê o comando `tc`), `bash` e o ambiente de desenvolvimento `R-base` com a biblioteca `jsonlite`.

---

## 4. Guia de Execução Passo a Passo

### Etapa 4.1: Preparação do Servidor na AWS

Após instanciar a máquina virtual na console AWS EC2, acesse o terminal do servidor via SSH através do terminal local:

```bash
ssh -i "sua-chave.pem" ubuntu@seu-ip-publico-aws

```

Atualize os repositórios da instância e instale o utilitário de medição:

```bash
sudo apt-get update
sudo apt-get install -y iperf3

```

Inicie o servidor `iperf3` em um loop infinito estruturado. Esse comando garante que, mesmo após o término de uma sessão de testes de 30 segundos, o receptor permaneça escutando na porta padrão (5201) sem encerrar o processo:

```bash
while true; do iperf3 -s -1; done

```

### Etapa 4.2: Configuração e Instalação de Dependências no Cliente (WSL2)

Abra o terminal do WSL2 no seu ambiente local. Instale todas as dependências do sistema operacional e as bibliotecas estatísticas do R necessárias para o parse de dados:

```bash
sudo apt-get update
sudo apt-get install -y iperf3 iproute2 r-base

```

Instale a dependência de leitura de JSON para o ambiente R via linha de comando:

```bash
sudo Rscript -e "install.packages('jsonlite', repos='http://cran.us.r-project.org')"

```

Crie o diretório do projeto e configure a estrutura de arquivos:

```bash
mkdir -p ~/experimento_redes/resultados_iperf_json
cd ~/experimento_redes

```

Crie os arquivos de automação e processamento utilizando o editor de texto de sua preferência (como o `nano`):

```bash
nano executar_testes.sh
nano processar_resultados_v2.R
nano gerar_graphics_banca.R

```

_Cole os respectivos códigos desenvolvidos para cada script em seus arquivos correspondentes, salve e feche os arquivos._

Conceda permissão de execução estrita para o script em Bash:

```bash
chmod +x executar_testes.sh

```

### Etapa 4.3: Execução Estratégica da Bateria de Testes (Divisão por Sessões)

#### Execução da Sessão 1 (Cenários: 0%, 1%, 3%)

Edite o arquivo `executar_testes.sh` para garantir que a matriz de laço de repetição contenha apenas os valores `0 1 3` na linha de definição das taxas de perda. Configure também a variável do IP de destino com o IP público atual da sua instância AWS.

Execute a primeira metade do experimento:

```bash
./executar_testes.sh

```

Aguarde a conclusão da primeira bateria (aproximadamente 1 hora e 30 minutos). Após o término, compacte os resultados gerados para evitar perdas caso a instância sofra timeout:

```bash
tar -czvf logs_metade_1.tar.gz resultados_iperf_json/

```

#### Execução da Sessão 2 (Cenários: 5%, 10%, 20%)

Se a sessão do laboratório AWS expirar, inicie uma nova sessão, ligue a instância EC2 e capture o novo IP público gerado. No terminal do servidor AWS, reinicie o loop receptor do `iperf3`.

No terminal do cliente local (WSL2), edite o arquivo `executar_testes.sh` modificando a linha de perdas para contemplar apenas os valores `5 10 20` e atualize o IP público se este tiver mudado.

Execute a segunda metade do experimento:

```bash
./executar_testes.sh

```

Aguarde a conclusão (mais 1 hora e 30 minutos).

### Etapa 4.4: Consolidação dos Dados e Análise Estatística

Com os logs das duas sessões armazenados na pasta `resultados_iperf_json`, execute o script de processamento de dados em R. Este script fará a varredura individual de cada um dos 360 arquivos JSON extraindo as chaves de desempenho bruto e útil:

```bash
Rscript processar_resultados_v2.R

```

Para validar se os dados foram compilados corretamente e se a tabela final não possui inconsistências, execute a leitura estruturada do arquivo CSV gerado diretamente no terminal:

```bash
Rscript -e "df <- read.csv('resumo_estatistico_final.csv'); print(df, row.names = FALSE)"

```

### Etapa 4.5: Geração de Matrizes Visuais para a Banca

Execute o script gráfico para gerar os três arquivos independentes de imagem que compõem a análise comparativa estruturada do comportamento das pilhas de protocolo:

```bash
Rscript gerar_graphics_banca.R

```

Para listar os arquivos gerados em formato de imagem de alta definição na pasta do projeto, utilize o comando:

```bash
ls -l *.png

```

---

## 5. Estrutura de Diretórios Completa

A árvore estrutural do projeto após a execução de todas as etapas deve se apresentar da seguinte forma:

```text
├── resultados_iperf_json/       # Diretório contendo os 360 arquivos .json brutos coletados
├── executar_testes.sh           # Script em Bash de automação do tc netem e execução do iperf3
├── processar_resultados_v2.R    # Script R que consolida os dados JSON em métricas estatísticas
├── gerar_graphics_banca.R       # Script R focado na plotagem independente das imagens A, B e C
├── resumo_estatistico_final.csv # Arquivo de dados consolidado com médias e desvios padrão
├── imagem_A_throughput.png      # Gráfico de barras: Vazão Bruta Injetada na Rede
├── imagem_B_goodput.png         # Gráfico de barras: Vazão Útil Recebida na Aplicação
└── imagem_C_loss_validation.png # Gráfico de barras: Validação de Perda Planejada vs Efetiva

```

---
