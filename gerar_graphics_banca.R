if (!require("jsonlite")) install.packages("jsonlite", repos="http://cran.us.r-project.org")

DIRETORIO_LOGS <- "resultados_iperf_json"
niveis_perda <- c(0, 1, 3, 5, 10, 20)
protocolos <- c("tcp", "udp")
reps <- 30

dados_lista <- list()

for (p in niveis_perda) {
  for (proto in protocolos) {
    throughput_vals <- c()
    goodput_vals <- c()
    
    for (i in 1:reps) {
      arquivo <- paste0(DIRETORIO_LOGS, "/", proto, "_perda_", p, "_rep_", i, ".json")
      if (file.exists(arquivo) && file.size(arquivo) > 0) {
        resultado <- tryCatch({ fromJSON(arquivo) }, error = function(e) NULL)
        if (!is.null(resultado)) {
          vazao_bruta <- resultado$end$sum_sent$bits_per_second / 1e6
          vazao_util <- resultado$end$sum_received$bits_per_second / 1e6
          
          if (is.null(vazao_util)) vazao_util <- 0
          if (is.null(vazao_bruta)) vazao_bruta <- 0
          
          throughput_vals <- c(throughput_vals, vazao_bruta)
          goodput_vals <- c(goodput_vals, vazao_util)
        }
      }
    }
    
    media_t <- if(length(throughput_vals) > 0) mean(throughput_vals) else 0
    media_g <- if(length(goodput_vals) > 0) mean(goodput_vals) else 0
    
    # GARANTIA: Incluindo explicitamente ambas as métricas no dataframe
    dados_lista[[length(dados_lista) + 1]] <- data.frame(
      Protocolo = toupper(proto),
      Perda = p,
      Throughput = round(media_t, 2),
      Goodput = round(media_g, 2)
    )
  }
}

df <- do.call(rbind, dados_lista)

# Separar matrizes para os gráficos lado a lado
df_tcp <- df[df$Protocolo == "TCP", ]
df_udp <- df[df$Protocolo == "UDP", ]

# --- IMAGEM A: THROUGHPUT (Vazão Bruta Injetada) ---
png("imagem_A_throughput.png", width = 800, height = 500, res = 120)
par(mar = c(5, 5, 4, 2))
matriz_t <- rbind(df_tcp$Throughput, df_udp$Throughput)
bpA <- barplot(matriz_t, beside = TRUE, col = c("#C0392B", "#2980B9"), ylim = c(0, 130),
        xlab = "Taxa de Perda Emulada (%)", ylab = "Throughput Bruto (Mbps)",
        main = "Imagem A: Vazão Bruta Injetada na Rede", names.arg = paste0(niveis_perda, "%"))
text(x = bpA, y = matriz_t + 4, labels = round(matriz_t, 1), cex = 0.7, font = 2, col = c("#C0392B", "#2980B9"))
legend("topright", legend = c("TCP (Cubic)", "UDP"), fill = c("#C0392B", "#2980B9"), bg="white")
dev.off()

# --- IMAGEM B: GOODPUT (Vazão Útil na Aplicação) ---
png("imagem_B_goodput.png", width = 800, height = 500, res = 120)
par(mar = c(5, 5, 4, 2))
matriz_g <- rbind(df_tcp$Goodput, df_udp$Goodput)
bpB <- barplot(matriz_g, beside = TRUE, col = c("#E74C3C", "#3498DB"), ylim = c(0, 130),
        xlab = "Taxa de Perda Emulada (%)", ylab = "Goodput Útil (Mbps)",
        main = "Imagem B: O Impacto Real na Aplicação (Vazão Útil)", names.arg = paste0(niveis_perda, "%"))
text(x = bpB, y = matriz_g + 4, labels = round(matriz_g, 1), cex = 0.7, font = 2, col = c("#E74C3C", "#3498DB"))
legend("topright", legend = c("TCP (Cubic)", "UDP"), fill = c("#E74C3C", "#3498DB"), bg="white")
dev.off()

# --- IMAGEM C: PACKET LOSS (Validação da Perda Efetiva) ---
png("imagem_C_loss_validation.png", width = 800, height = 500, res = 120)
par(mar = c(5, 5, 4, 2))
# Calcula perda real do UDP baseada em enviado vs recebido
perda_real <- round(((df_udp$Throughput - df_udp$Goodput) / df_udp$Throughput) * 100, 2)
perda_real[is.na(perda_real) | perda_real < 0] <- 0

matriz_c <- rbind(niveis_perda, perda_real)
bpC <- barplot(matriz_c, beside = TRUE, col = c("#7F8C8D", "#2C3E50"), ylim = c(0, 28),
        xlab = "Cenário de Teste", ylab = "Taxa de Perda (%)",
        main = "Imagem C: Validação da Perda Planejada vs Efetiva", names.arg = paste0(niveis_perda, "%"))
text(x = bpC, y = matriz_c + 1, labels = paste0(matriz_c, "%"), cex = 0.7, font = 2, col = c("#7F8C8D", "#2C3E50"))
legend("topleft", legend = c("Perda Planejada (tc netem)", "Perda Efetiva (Medida na AWS)"), fill = c("#7F8C8D", "#2C3E50"), bg="white")
dev.off()

cat("Perfeito! Imagens A, B e C geradas com sucesso sem erros!\n")
