# =============================================================================
# CARREGAMENTO DE DADOS 
# =============================================================================

cat(">>> Baixando dados do Yahoo Finance...\n")

# Definição de datas
start_date <- as.Date("2014-09-18")
end_date   <- as.Date("2026-01-31")
split_date_etf <- as.Date("2024-01-11") # ETF de BTC aprovado dia 10 e início efetivo dia 11D
#split_date_etf <- as.Date("2023-10-23") # Grayscale vence - ETF de BTC futuro aprovado dia 10 e início efetivo dia 11D
root_dir <- tryCatch(# Raiz do projeto (compatível com RStudio + renv)
  rprojroot::find_root(rprojroot::is_rstudio_project),
  error = function(e) getwd()
)
out_dir <- file.path(root_dir, "Resultados", "Dados")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# Função utilitária: xts -> Excel com coluna Date
write_xts_xlsx <- function(x, filename, out_dir) {
  stopifnot(!missing(x), !missing(filename), !missing(out_dir))
  
  df <- data.frame(
    Date = as.Date(zoo::index(x)),
    coredata(x),
    check.names = FALSE
  )
  
  path <- file.path(out_dir, filename)
  openxlsx::write.xlsx(df, path, overwrite = TRUE)
  
  message("\nArquivo Excel salvo em: ", normalizePath(path, winslash = "\\", mustWork = FALSE))
  invisible(path)
}

# Download 
tryCatch({
  btc_raw <- getSymbols("BTC-USD", src="yahoo", from=start_date, to=end_date, auto.assign = FALSE)
  vix_raw <- getSymbols("^VIX", src="yahoo", from=start_date, to=end_date, auto.assign = FALSE)
}, error=function(e) { 
  stop("\nErro crítico: Falha no download. Verifique sua conexão.\n") 
})

write_xts_xlsx(btc_raw, "BTC.xlsx", out_dir)
write_xts_xlsx(vix_raw, "VIX.xlsx", out_dir)

# Tratamento e Retornos
btc_close <- Ad(btc_raw)
vix_close <- Ad(vix_raw)

# Merge (Garante alinhamento temporal)
data_merged <- merge(btc_close, vix_close, join="inner")
colnames(data_merged) <- c("BTC", "VIX") 
data_prices <- na.omit(data_merged)


rets <- data_prices
rets$BTC <- diff(log(data_prices$BTC)) * 100

# Retornos Logarítmicos (VARIÁVEL BASE DO MODELO)
###rets <- diff(log(data_prices)) * 100
rets <- na.omit(rets)
NAMES <- colnames(rets) 

write_xts_xlsx(rets, "ret_BTC_VIX_emLinha.xlsx", out_dir)

cat(">>> Dados carregados. Amostra total:", nrow(rets), "observações.\n")