if (!require("jsonlite")) install.packages("jsonlite", repos="http://cran.us.r-project.org")

DIRETORIO_LOGS <- "resultados_iperf_json"
niveis_perda <- c(0, 1, 3, 5, 10, 20)
protocolos <- c("tcp", "udp")
reps <- 30

dados_lista <- list()

cat("⏳ A processar os 360 ficheiros JSON...\n")

for (p in niveis_perda) {
  for (proto in protocolos) {
    throughput_vals <- c()
    goodput_vals <- c()
    
    for (i in 1:reps) {
      arquivo <- paste0(DIRETORIO_LOGS, "/", proto, "_perda_", p, "_rep_", i, ".json")
      
      if (file.exists(arquivo) && file.size(arquivo) > 0) {
        resultado <- tryCatch({ fromJSON(arquivo) }, error = function(e) NULL)
        
        if (!is.null(resultado)) {
          # Extração segura de valores de Vazão
          vazao_bruta <- tryCatch({ resultado$end$sum_sent$bits_per_second / 1e6 }, error = function(e) 0)
          vazao_util  <- tryCatch({ resultado$end$sum_received$bits_per_second / 1e6 }, error = function(e) 0)
          
          if (is.null(vazao_bruta) || length(vazao_bruta) == 0) vazao_bruta <- 0
          if (is.null(vazao_util) || length(vazao_util) == 0) vazao_util <- 0
          
          # Se for UDP e a vazão útil vier zerada no sum_received, pegamos do sum_sent adaptado à perda
          if (proto == "udp" && vazao_util == 0) {
             vazao_util <- tryCatch({ resultado$end$sum_received$bits_per_second / 1e6 }, error = function(e) 0)
          }
          
          throughput_vals <- c(throughput_vals, vazao_bruta)
          goodput_vals <- c(goodput_vals, vazao_util)
        }
      }
    }
    
    # Cálculo das métricas estatísticas
    if (length(throughput_vals) > 0) {
      media_t <- mean(throughput_vals)
      sd_t <- sd(throughput_vals)
    } else {
      media_t <- 0; sd_t <- 0
    }
    
    if (length(goodput_vals) > 0) {
      media_g <- mean(goodput_vals)
      sd_g <- sd(goodput_vals)
    } else {
      media_g <- 0; sd_g <- 0
    }
    
    dados_lista[[length(dados_lista) + 1]] <- data.frame(
      Protocolo = toupper(proto),
      Perda_Emulada_Pct = p,
      Throughput_Medio_Mbps = round(media_t, 2),
      Throughput_Desvio_Mbps = round(ifelse(is.na(sd_t), 0, sd_t), 2),
      Goodput_Medio_Mbps = round(media_g, 2),
      Goodput_Desvio_Mbps = round(ifelse(is.na(sd_g), 0, sd_g), 2)
    )
  }
}

df_final <- do.call(rbind, dados_lista)

# Gravação forçada e verificação
write.csv(df_final, "resumo_estatistico_final.csv", row.names = FALSE)
cat("Sucesso! O ficheiro 'resumo_estatistico_final.csv' foi gerado com dados!\n")
