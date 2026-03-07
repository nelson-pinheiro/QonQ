# =============================================================================
# PRINCIPAL
# =============================================================================
cat("\014") # Limpa console
rm(list=ls()) # Limpa memória
inicio <- Sys.time()
options(scipen=999) 


source("LoadPackages.R")

# Diretórios
dirs <- c("Resultados", "Resultados/Figuras", "Resultados/Tabelas", "Resultados/Robustez", "Resultados/Dados")
sapply(dirs, function(x) if(!dir.exists(x)) dir.create(x, recursive=TRUE))

source("LoadData.R")

source("MakeStatistics.R")

source("Models.R")

source("FinalPlots.R")

fim <- Sys.time()
cat(sprintf("\nProcesso Finalizado. Tempo Total: %.2f min\n", as.numeric(difftime(fim, inicio, units="mins"))))