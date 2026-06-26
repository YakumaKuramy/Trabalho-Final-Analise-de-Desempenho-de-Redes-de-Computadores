# Analise de Desempenho de Protocolos de Transporte: TCP CUBIC vs UDP em Redes com Perda de Pacotes

Este repositório contém o ambiente automatizado, os scripts de coleta, os mecanismos de processamento estatístico e os resultados de um experimento sistemático projetado para analisar o impacto da perda de pacotes emulada no Throughput (vazão bruta) e Goodput (vazão útil) dos protocolos TCP (Cubic) e UDP.

O experimento consiste em 360 testes automatizados divididos em 30 réplicas estatísticas para cada cenário de perda planejado (0%, 1%, 3%, 5%, 10% e 20%). A arquitetura utiliza uma topologia cliente-servidor distribuída entre o ambiente local (WSL2) e a nuvem (AWS).

## 1. Dimensionamento de Tempo e Mitigação de Riscos na AWS

O tempo bruto para a execução de toda a bateria de testes automatizados é de aproximadamente 180 minutos (3 horas). No entanto, o AWS Learner Lab impõe um limite estrito de **4 horas** por sessão ativa, encerrando todas as instâncias EC2 compulsoriamente após esse período.

Se o operador utilizar a mesma sessão para criar instâncias, configurar grupos de segurança, depurar chaves SSH e validar a conectividade, o tempo restante será insuficiente para garantir a execução contínua das 360 réplicas, resultando na perda total dos logs em andamento.

### Estratégia de Mitigação: Divisão em Duas Sessões

Para neutralizar o risco de timeout, o experimento deve ser planejado estritamente em duas sessões consecutivas do laboratório:

- **Sessão 1: Preparação e Homologação:** Destinada à configuração de infraestrutura, liberação de portas de firewall (Security Groups), testes manuais de conectividade com o iperf3, instalação de pacotes no WSL2 e validação dos scripts. Esta sessão pode expirar ou ser encerrada propositalmente após os testes iniciais.
- **Sessão 2: Execução Dedicada (Produção):** Inicialização de uma nova sessão limpa com o cronômetro zerado em 4 horas. O operador conecta-se diretamente à instância utilizando o aprendizado da sessão anterior e dispara o script imediatamente, garantindo uma margem de segurança de 1 hora.

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

### Análise Visual dos Dados

Abaixo estão os gráficos consolidados que demonstram o comportamento dinâmico das pilhas de protocolos sob estresse:

#### Imagem A: Vazão Bruta Injetada na Rede (Throughput)

Demonstra o volume de tráfego injetado na interface de rede pelo transmissor. Evidencia a agressividade do UDP em manter a saturação do canal próximo ao teto nominal configurado (100 Mbps) em contraste com o recuo imediato do algoritmo CUBIC do TCP.

#### Imagem B: O Impacto Real na Aplicação (Goodput / Vazão Útil)

Ilustra o volume de dados efetivamente entregue à camada de aplicação no destino. Revela o "efeito penhasco" sofrido pelo TCP Cubic, cuja vazão útil entra em colapso prático (menos de 3 Mbps) a partir de 1% de perda de pacotes.

#### Imagem C: Validação da Perda Planejada vs Efetiva

Gráfico de controle metodológico que compara as taxas de descarte injetadas artificialmente via kernel com o percentual de perda real contabilizado estatisticamente pelo receptor na AWS.

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

### Etapa 4.1: Sessão 1 - Homologação de Infraestrutura e Redes

Acesse o console da AWS, inicie o laboratório do Learner Lab e crie uma instância EC2 executando o Ubuntu Server. No painel de gerência da EC2, localize o Security Group vinculado à instância e adicione uma regra de entrada permitindo conexões na porta TCP 5201 e UDP 5201 originadas do IP público da sua rede local.

Abra o terminal do seu ambiente local (WSL2) e conecte-se à instância EC2 via SSH utilizando a sua chave privada `.pem`:

```bash
ssh -i "sua-chave.pem" ubuntu@seu-ip-publico-aws

```

Uma vez autenticado no servidor da AWS, atualize a lista de repositórios do sistema operacional e instale o software de medição de performance:

```bash
sudo apt-get update
sudo apt-get install -y iperf3

```

Inicie o receptor do iperf3 em modo padrão para testar a conectividade básica:

```bash
iperf3 -s

```

Abra uma segunda aba no terminal do seu WSL2 local (mantendo a conexão SSH aberta na primeira) e dispare um teste rápido de 5 segundos para testar a liberação das portas e do Security Group:

```bash
# Teste de conectividade TCP
iperf3 -c seu-ip-publico-aws -t 5

# Teste de conectividade UDP
iperf3 -c seu-ip-publico-aws -u -b 10M -t 5

```

Se ambos os testes exibirem relatórios de vazão na tela, a infraestrutura está homologada. Feche a sessão do laboratório AWS para zerar o cronômetro de 4 horas.

### Etapa 4.2: Sessão 2 - Instalação de Dependências e Preparação do Experimento

Inicie uma nova sessão do AWS Learner Lab para obter uma janela limpa de 4 horas. Ligue a instância EC2 e capture o novo endereço IP público associado a ela.

Acesse o servidor via SSH através do terminal local:

```bash
ssh -i "sua-chave.pem" ubuntu@novo-ip-publico-aws

```

Execute o comando em loop infinito para garantir que o processo do iperf3 reinicie automaticamente após cada réplica terminada, permanecendo pronto para receber conexões sem intervenção manual:

```bash
while true; do iperf3 -s -1; done

```

Retorne ao terminal local do WSL2 para instalar os pacotes essenciais do sistema e o ambiente R utilizado para as análises matemáticas:

```bash
sudo apt-get update
sudo apt-get install -y iperf3 iproute2 r-base

```

Instale a biblioteca de manipulação de arquivos JSON dentro do ambiente estatístico R:

```bash
sudo Rscript -e "install.packages('jsonlite', repos='http://cran.us.r-project.org')"

```

Crie o diretório de trabalho estruturado e mude para a pasta recém-criada:

```bash
mkdir -p ~/experimento_redes/resultados_iperf_json
cd ~/experimento_redes

```

Crie os arquivos vazios que receberão os scripts de automação, processamento e renderização de imagens:

```bash
nano executar_testes.sh
nano processar_resultados_v2.R
nano gerar_graphics_banca.R

```

_Abra cada arquivo individualmente utilizando o editor de texto, insira os respectivos códigos validados, salve e feche os arquivos._

Atribua permissões estritas de execução para o script de controle em Bash:

```bash
chmod +x executar_testes.sh

```

### Etapa 4.3: Execução da Automação de Coleta

Abra o arquivo `executar_testes.sh` e atualize a variável que aponta para a infraestrutura de nuvem com o novo IP público capturado no início da Sessão 2.

Inicie o processo de coleta automatizada:

```bash
./executar_testes.sh

```

_O terminal exibirá o avanço individual de cada uma das 360 réplicas. Não interrompa o processo nem permita que a máquina hospedeira entre em modo de suspensão ou hibernação durante as 3 horas de execução._

### Etapa 4.4: Consolidação dos Dados e Análise Estatística

Após a conclusão das 360 réplicas (sinalizadas pela mensagem final do script em Bash), execute o processamento lógico em R. O script irá varrer a pasta de logs brutos, extrair as chaves JSON necessárias e compilar as médias e desvios padrão:

```bash
Rscript processar_resultados_v2.R

```

Valide a integridade do arquivo de dados consolidado imprimindo a estrutura da tabela final diretamente na tela do terminal:

```bash
Rscript -e "df <- read.csv('resumo_estatistico_final.csv'); print(df, row.names = FALSE)"

```

### Etapa 4.5: Renderização dos Gráficos para o Repositório

Execute o script visual em R para processar a matriz de dados e gerar as imagens comparativas no formato `.png`:

```bash
Rscript gerar_graphics_banca.R

```

Para confirmar que os arquivos de imagem foram gravados no diretório com as dimensões corretas, execute a listagem do diretório filtrando pela extensão:

```bash
ls -l *.png

```

---

## 5. Estrutura de Diretórios Completa

A árvore estrutural do projeto após a conclusão de todas as fases descritas neste guia deve se apresentar exatamente da seguinte forma:

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
