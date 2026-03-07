# =============================================================================
# 3. CONFIGURAÇÃO Q-ON-Q
# =============================================================================

# Parâmetros (incluir Robustez nas listas quando desejável)
windows_robustness <- c( 200 ) # tamanho da janela
nlag <- 2   # 1 defasagem
forecast_robustness <- c( 20 )   # horizonte de previsão 


quantiles <- seq(0.05, 0.95, 0.1)  
m <- length(quantiles)
analysis_periods <- c("PRE_ETF","POST_ETF") ##c("FULL_SAMPLE", "PRE_ETF","POST_ETF")

cat("\n>>> Iniciando Loops de Estimação Quantile-on-Quantile...\n")

for (period_name in analysis_periods) {
  cat(paste0("\n--- Período: ", period_name, " ---\n"))
  for (forecast_horizon in forecast_robustness) {
    for (win_size in windows_robustness) {
      cat(sprintf("\n Processando janela %d previsão %d \n", win_size, forecast_horizon))
      # A. SELEÇÃO DE DADOS
      if (period_name == "FULL_SAMPLE") {
        data_run <- rets
        tag <- "TOTAL"
      } else if (period_name == "PRE_ETF") {
        data_run <- rets[index(rets) < split_date_etf, ]
        tag <- "PRÉ-ETF"
      } else if (period_name == "POST_ETF") {
        idx_start <- which(index(rets) >= split_date_etf)[1]
        # Garante buffer para janela móvel no loop de estimação, se necessário
        # Mas para a estatística descritiva acima, usamos o corte puro.
        idx_look <- max(1, idx_start - win_size)
        data_run <- rets[idx_look:nrow(rets), ]
        tag <- "PÓS-ETF"
      }
      
      if (nrow(data_run) <= win_size + 20) {
        cat("   [PULANDO] Dados insuficientes para janela W=", win_size, "\n")
        next
      }
      
      # Configuração de Armazenamento Dinâmico 
      t0 <- nrow(data_run) - win_size
      TCI_3D <- array(NA_real_, dim = c(t0, m, m)) # Cubo para guardar a série temporal de cada par
      
      # Nomes de Arquivo
      dt_ini <- format(start(data_run) + win_size, "%Y%m%d")
      dt_fim <- format(end(data_run), "%Y%m%d")
      fname_suf <- paste0("_", dt_ini, "_", dt_fim, "_", tag, "_W", win_size, "_H", forecast_horizon)
      folder <- "Resultados/Figuras"
      
      cat(paste0("    -> Processando W=", win_size, "H=", forecast_horizon, " [Matriz ", m, "x", m, "]... \n"))
      
      # B. ESTIMAÇÃO
      NET <- matrix(NA, m, m, dimnames = list(quantiles, quantiles))
      TCI <- matrix(NA, m, m, dimnames = list(quantiles, quantiles))
      
      pb <- txtProgressBar(min = 0, max = m*m, style = 3)
      count <- 0
      errors_count <- 0
      
      # LOOP DUPLO Q-ON-Q
      for (i in 1:m) {        
        for (j in 1:m) {      
          count <- count + 1
          setTxtProgressBar(pb, count)
          
          tryCatch({
            dca <- ConnectednessApproach(
              x = data_run, 
              nlag = nlag, 
              nfore = forecast_horizon, 
              window.size = win_size, 
              corrected=TRUE,
              model = "QVAR", 
              connectedness = "Time",
              VAR_config = list(QVAR = list(tau = c(quantiles[i], quantiles[j])))
            )
            
            # Médias Estáticas
            if(!is.null(dca$NET) && ncol(dca$NET) >= 1) {
              NET[i, j] <- mean(dca$NET[,1], na.rm=TRUE)
            }
            if(!is.null(dca$TCI)) {
              TCI[i, j] <- mean(dca$TCI, na.rm=TRUE)
              
              # Armazenamento Dinâmico
              if(length(dca$TCI) == t0) {
                TCI_3D[, i, j] <- dca$TCI
              } else if (length(dca$TCI) > t0) {
                TCI_3D[, i, j] <- tail(dca$TCI, t0)
              }
            }
            
          }, error = function(e) {
            errors_count <<- errors_count + 1
          })
        }
      }
      close(pb)
      
      if(errors_count > 0) cat(paste0("\n    [AVISO] ", errors_count, " pares falharam na convergência.\n"))
      else {cat("\nProcessamento sem erros.\n")}
      
      # C. PLOTAGEM 
      
      # --- 1. HEATMAP TCI ---
      if(!all(is.na(TCI))) {
        melted_TCI <- melt(TCI)
        colnames(melted_TCI) <- c("Q_BTC", "Q_VIX", "value")
        melted_TCI$Q_BTC <- as.numeric(as.character(melted_TCI$Q_BTC))
        melted_TCI$Q_VIX <- as.numeric(as.character(melted_TCI$Q_VIX))
        
        p_TCI <- ggplot(data = melted_TCI, aes(x=Q_VIX, y=Q_BTC, fill=value)) + 
          geom_tile(color = "white", size=0.2) + 
          geom_text(aes(label = sprintf("%.2f", value)), color = "black", size = 2.5) + 
          scale_fill_gradientn(colours=c("white", "#eff3ff", "#bdd7e7", "#6baed6", "#2171b5"), 
                               na.value = "grey90", name="TCI") +
          scale_x_continuous(breaks = quantiles) +
          scale_y_continuous(breaks = quantiles) +
          labs(x = "Quantis VIX", y = "Quantis BTC", 
               title = paste0("Total Connectedness (TCI): ", tag)) +
          coord_fixed() + theme_minimal() +
          theme(panel.grid = element_blank())
        
        print(p_TCI)
        ggsave(file.path(folder, paste0("TCI_HEATMAP_", fname_suf, ".png")), p_TCI, width=7, height=6)
      }
      
      # --- 2. HEATMAP NET (COM VALORES) ---
      if(!all(is.na(NET))) {
        melted_NET <- melt(NET)
        colnames(melted_NET) <- c("Q_BTC", "Q_VIX", "value")
        melted_NET$Q_BTC <- as.numeric(as.character(melted_NET$Q_BTC))
        melted_NET$Q_VIX <- as.numeric(as.character(melted_NET$Q_VIX))
        
        max_abs <- max(abs(melted_NET$value), na.rm=TRUE)
        if(max_abs == 0) max_abs <- 1 
        
        p_NET <- ggplot(data = melted_NET, aes(x=Q_VIX, y=Q_BTC, fill=value)) + 
          geom_tile(color = "white", size=0.2) + 
          geom_text(aes(label = sprintf("%.2f", value)), color = "black", size = 2.5) + 
          scale_fill_gradient2(low = "#b2182b", mid = "white", high = "#2166ac", 
                               midpoint = 0, limit = c(-max_abs, max_abs), space = "Lab", 
                               na.value = "grey90", name = "NET") +
          scale_x_continuous(breaks = quantiles) +
          scale_y_continuous(breaks = quantiles) +
          labs(x = "Quantis VIX", y = "Quantis BTC", 
               title = paste0("Net Spillovers BTC: ", tag),
               subtitle = "Azul (>0): Exportador Líquido | Vermelho (<0): Importador Líquido") +
          coord_fixed() + theme_minimal() +
          theme(panel.grid = element_blank())
        
        print(p_NET)
        ggsave(file.path(folder, paste0("NET_HEATMAP_", fname_suf, ".png")), p_NET, width=7, height=6)
      }
      
      # --- 3. GRÁFICO TEMPORAL: DIRECT vs REVERSE vs DELTA (GABAUER STYLE) ---
      
      dates_vec <- index(data_run)[(win_size+1):nrow(data_run)]
      if(length(dates_vec) > t0) dates_vec <- tail(dates_vec, t0)
      
      if (t0 > 0 && !all(is.na(TCI_3D))) {
        direct_tci <- numeric(t0)
        reverse_tci <- numeric(t0)
        
        for (k in 1:t0) {
          mat_t <- TCI_3D[k,,]
          if (!all(is.na(mat_t))) {
            # Direct: Diagonal Principal (0.1|0.1 ... 0.9|0.9)
            direct_tci[k] <- mean(diag(mat_t), na.rm=TRUE)
            # Reverse: Diagonal Secundária (0.1|0.9 ... 0.9|0.1)
            reverse_tci[k] <- mean(diag(mat_t[nrow(mat_t):1, ]), na.rm=TRUE)
          } else {
            direct_tci[k] <- NA
            reverse_tci[k] <- NA
          }
        }
        
        df_dyn <- data.frame(Date = dates_vec, 
                             Direct = direct_tci, 
                             Reverse = reverse_tci,
                             Delta = reverse_tci - direct_tci) # Delta calculado como Gabauer 2023
        #__________________________________
        # Export TCI data
        df_dyn_export <- df_dyn
        df_dyn_export$Date <- as.Date(df_dyn_export$Date)  # garante data "limpa" no Excel
        out_tab_dir <- "Resultados/Dados"
        if (!dir.exists(out_tab_dir)) dir.create(out_tab_dir, recursive = TRUE)
        xlsx_file <- file.path(out_tab_dir, paste0("DYNAMIC_TCI_TABLE_", fname_suf, ".xlsx"))
        
        openxlsx::write.xlsx(
          x = df_dyn_export,
          file = xlsx_file,
          overwrite = TRUE
        )
        
        cat("   [OK] Tabela Excel (Dynamic TCI) salva em: ", xlsx_file, "\n")
        #_________________________________
        
        # Melt incluindo o Delta
        melted_dyn <- melt(df_dyn, id.vars = "Date", measure.vars = c("Direct", "Reverse", "Delta"))
        
        
        
        
        
        p_lines <- ggplot(melted_dyn, aes(x=Date, y=value, color=variable)) +
          # Linha zero de referência para o Delta
          geom_hline(yintercept=0, linetype="dashed", color="grey50") +
          geom_line(linewidth=0.8) +
          # Cores: Direct (Azul), Reverse (Vermelho), Delta (Preto)
          scale_color_manual(values = c("Direct" = "#2166ac", "Reverse" = "#b2182b", "Delta" = "black")) +
          labs(x = NULL, y = "Connectedness (%)", color = "Séries",
               title = paste0("Dynamic Total Connectedness: ", tag),
               subtitle = "Direct (Regimes Iguais) | Reverse (Regimes Opostos) | Delta (Líquido = Reverse - Direct)") +
          theme_minimal() +
          theme(legend.position = "bottom") +
          scale_x_date(date_labels = "%Y", date_breaks = "1 year")
        
        print(p_lines)
        ggsave(file.path(folder, paste0("TCI_SERIES_", fname_suf, ".png")), p_lines, width=10, height=6)
      }
    }
  }
}