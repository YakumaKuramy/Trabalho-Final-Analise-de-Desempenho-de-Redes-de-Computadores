#!/bin/bash

# ==============================================================================
# SCRIPT DE AUTOMAÇÃO DE EXPERIMENTOS DE REDE - EQUIPE 13
# Disciplina: Análise de Desempenho de Redes de Computadores (UFC)
# Integrantes: Marcos Paulo e Maria Luiza
# ==============================================================================

# --- CONFIGURAÇÕES DE INFRAESTRUTURA ---
SERVER_IP="54.227.41.78"  # Substitua pelo IP público da VM Servidor-Avaliacao-Transporte
INTERFACE="eth0"                      # Interface de rede padrão do WSL2 (verifique com 'ip a')

# --- PARÂMETROS DO EXPERIMENTO (FIXOS) ---
DURATION=30                           # Duração exata exigida pelo planejamento (30s)
REPLICAS=30                           # Quantidade de amostras por cenário (n=30)
BANDWIDTH="100M"                      # Teto máximo de 100 Mbps para manter o teste justo

# --- FATORES E NÍVEIS (VARIÁVEIS) ---
PERDAS=(0 1 3 5 10 20)

# Criar estrutura de subdiretórios para guardar as saídas brutas
OUTPUT_DIR="resultados_iperf_json"
mkdir -p "$OUTPUT_DIR"

echo "======================================================================"
echo " INICIANDO EXPERIMENTO SISTEMÁTICO: 360 TESTES AUTOMATIZADOS "
echo "======================================================================"
echo "Destino: VM AWS ($SERVER_IP) | Teto de Banda: $BANDWIDTH | Duração: ${DURATION}s"

for perda in "${PERDAS[@]}"; do
    echo ""
    echo ">>>> CONFIGURANDO NÍVEL DE PERDA EMULADA: ${perda}% <<<<"
    
    # 1. Limpeza preventiva de regras antigas do TC
    sudo tc qdisc del dev "$INTERFACE" root 2>/dev/null
    
    # 2. Injeção do Monstrinho (Módulo Netem) se a perda for maior que 0%
    if [ "$perda" -gt 0 ]; then
        echo "Aplicando delay/loss artificial via tc/netem..."
        sudo tc qdisc add dev "$INTERFACE" root netem loss "${perda}%"
    else
        echo "Cenário de Controle (Rede Perfeita - 0% de perda)."
    fi
    
    # 3. Bloco de Execução do Protocolo TCP
    echo "Iniciando bateria de $REPLICAS réplicas para o protocolo [TCP]..."
    for i in $(seq 1 "$REPLICAS"); do
        echo -n "  -> [TCP] Executando réplica $i de $REPLICAS... "
        
        # Dispara o iperf3 salvando em JSON puro
        iperf3 -c "$SERVER_IP" -t "$DURATION" -b "$BANDWIDTH" --json > "${OUTPUT_DIR}/tcp_perda_${perda}_rep_${i}.json"
        
        sleep 2 # Tempo de resfriamento para o buffer da rede esvaziar
        echo "Concluído com sucesso."
    done
    
    # 4. Bloco de Execução do Protocolo UDP
    echo "Iniciando bateria de $REPLICAS réplicas para o protocolo [UDP]..."
    for i in $(seq 1 "$REPLICAS"); do
        echo -n "  -> [UDP] Executando réplica $i de $REPLICAS... "
        
        # O parâmetro '-u' força a geração de tráfego UDP
        iperf3 -c "$SERVER_IP" -u -t "$DURATION" -b "$BANDWIDTH" --json > "${OUTPUT_DIR}/udp_perda_${perda}_rep_${i}.json"
        
        sleep 2
        echo "Concluído com sucesso."
    done
done

# --- FINALIZAÇÃO E LIMPEZA DA INFRAESTRUTURA ---
echo ""
echo "Limpando as configurações da interface de rede local..."
sudo tc qdisc del dev "$INTERFACE" root 2>/dev/null

echo "======================================================================"
echo " EXPERIMENTO FINALIZADO: TOTAL DE 360 ARQUIVOS JSON GERADOS COM SUCESSO!"
echo "======================================================================"
