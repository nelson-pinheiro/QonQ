# =============================================================================
# 2.1 ESTATÍSTICAS DESCRITIVAS E TESTES ROBUSTOS
# =============================================================================
cat("\n>>> Calculando Estatísticas Descritivas iniciais (Tabela 1)...\n")

# Função auxiliar para gerar linha de estatísticas acadêmicas
calc_stats_acad <- function(series_xts, nome_periodo) {
  # Input deve ser objeto xts com colunas nomeadas
  
  cols <- colnames(series_xts)
  result_list <- list()
  
  for(var in cols) {
    x <- coredata(series_xts[, var])
    
    # Estatísticas Básicas
    obs <- length(x)
    media <- mean(x)
    mediana <- median(x)
    maximo <- max(x)
    minimo <- min(x)
    desvio <- sd(x)
    assimetria <- skewness(x)
    curtose <- kurtosis(x, excess = FALSE) # Excess Kurtosis requer cuidado, moments::kurtosis retorna Pearson (Normal=3)
    
    # Testes Formais
    jb_test <- jarque.bera.test(x)
    
    # Estacionariedade
    adf_test <- adf.test(x, alternative = "stationary")
    pp_test  <- pp.test(x) # Phillips-Perron (Robusto a heterocedasticidade)
    
    # Heterocedasticidade Condicional (ARCH-LM)
    # Usamos lags=12 para capturar dependência mensal aproximada ou microestrutura
    arch_test <- ArchTest(x, lags=12) 
    
    # Montagem do DF
    df <- data.frame(
      Periodo = nome_periodo,
      Variavel = var,
      Obs = obs,
      Mean = round(media, 4),
      Median = round(mediana, 4),
      Max = round(maximo, 4),
      Min = round(minimo, 4),
      StdDev = round(desvio, 4),
      Skewness = round(assimetria, 4),
      Kurtosis = round(curtose, 4),
      JB_Stat = round(jb_test$statistic, 2),
      JB_Pval = round(jb_test$p.value, 4),
      ADF_Stat = round(adf_test$statistic, 2),
      ADF_Pval = round(adf_test$p.value, 4),
      PP_Stat = round(pp_test$statistic, 2),
      PP_Pval = round(pp_test$p.value, 4),
      ARCH_Stat = round(arch_test$statistic, 2),
      ARCH_Pval = round(arch_test$p.value, 4)
    )
    result_list[[var]] <- df
  }
  return(do.call(rbind, result_list))
}

rets <- data_prices

# Definição dos Subconjuntos de Dados
rets_pre  <- rets[index(rets) < split_date_etf, ]
rets_post <- rets[index(rets) >= split_date_etf, ]

# Cálculo das Tabelas
tab_total <- calc_stats_acad(rets, "FULL_SAMPLE")
tab_pre   <- calc_stats_acad(rets_pre, "PRE_ETF")
tab_post  <- calc_stats_acad(rets_post, "POST_ETF")

# Exibição no Console
cat("\n--- ESTATÍSTICAS: FULL SAMPLE ---\n")
print(tab_total)
cat("\n--- ESTATÍSTICAS: PRE ETF ---\n")
print(tab_pre)
cat("\n--- ESTATÍSTICAS: POST ETF ---\n")
print(tab_post)

# Exportação para Excel
wb <- createWorkbook()
addWorksheet(wb, "Full_Sample")
writeData(wb, "Full_Sample", tab_total)
addWorksheet(wb, "Pre_ETF")
writeData(wb, "Pre_ETF", tab_pre)
addWorksheet(wb, "Post_ETF")
writeData(wb, "Post_ETF", tab_post)

saveWorkbook(wb, file.path("Resultados/Tabelas", "Estatisticas_Descritivas_Iniciais.xlsx"), overwrite = TRUE)
cat("\n[OK] Tabela de Estatísticas salva em 'Resultados/Tabelas/Estatisticas_Descritivas_Iniciais.xlsx'\n")
