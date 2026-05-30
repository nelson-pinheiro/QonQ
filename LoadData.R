# =============================================================================
# CARREGAMENTO DE DADOS 
# =============================================================================

cat(">>> Carregando dados...\n")

# -----------------------------------------------------------------------------
# CONFIGURAÇÃO DE FONTE (editável)
#   "yahoo" -> getSymbols("BTC-USD") via quantmod   (comportamento original)
#   "cmc"   -> CoinMarketCap via pacote crypto2 (Rota A)
# Observação: o VIX SEMPRE vem do Yahoo (índice CBOE, indisponível no CMC).
# -----------------------------------------------------------------------------
FONTE_BTC <- "cmc"   # alterne entre "yahoo" e "cmc"

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

# -----------------------------------------------------------------------------
# Função: obtém BTC via CoinMarketCap (crypto2) e devolve xts no formato OHLCV
# compatível com o objeto retornado por quantmod::getSymbols("BTC-USD").
# -----------------------------------------------------------------------------
get_btc_cmc <- function(from, to) {
  if (!requireNamespace("crypto2", quietly = TRUE)) {
    stop("Pacote 'crypto2' ausente. Instale com install.packages('crypto2') e rode renv::snapshot().",
         call. = FALSE)
  }
  
  moedas <- crypto2::crypto_list(only_active = TRUE)
  btc    <- moedas[moedas$slug == "bitcoin", , drop = FALSE]
  stopifnot("BTC nao encontrado no catalogo CMC" = nrow(btc) == 1L)
  
  hist <- crypto2::crypto_history(
    coin_list  = btc,
    convert    = "USD",
    start_date = format(as.Date(from), "%Y-%m-%d"),
    end_date   = format(as.Date(to),   "%Y-%m-%d"),
    interval   = "1d",
    sleep      = 1
  )
  
  # Monta xts com mesmas colunas/nomes que getSymbols produziria.
  # crypto2 nao possui preco "ajustado"; usamos close como Adjusted.
  dts <- as.Date(hist$timestamp)
  mat <- cbind(
    Open     = hist$open,
    High     = hist$high,
    Low      = hist$low,
    Close    = hist$close,
    Volume   = hist$volume,
    Adjusted = hist$close
  )
  x <- xts::xts(mat, order.by = dts)
  colnames(x) <- paste0("BTC.", colnames(x))  # BTC.Open, BTC.High, ... BTC.Adjusted
  x <- x[!duplicated(zoo::index(x)), ]
  xts::xts(x, order.by = zoo::index(x))
}

# Download 
tryCatch({
  if (identical(FONTE_BTC, "yahoo")) {
    cat(">>> Fonte BTC: Yahoo Finance (getSymbols)\n")
    btc_raw <- getSymbols("BTC-USD", src = "yahoo", from = start_date, to = end_date, auto.assign = FALSE)
  } else if (identical(FONTE_BTC, "cmc")) {
    cat(">>> Fonte BTC: CoinMarketCap (crypto2 / Rota A)\n")
    btc_raw <- get_btc_cmc(from = start_date, to = end_date)
  } else {
    stop("FONTE_BTC invalida: use 'yahoo' ou 'cmc'.", call. = FALSE)
  }
  
  # VIX sempre via Yahoo (indice CBOE, indisponivel no CMC)
  vix_raw <- getSymbols("^VIX", src = "yahoo", from = start_date, to = end_date, auto.assign = FALSE)
}, error=function(e) { 
  stop("\nErro crítico: Falha no download (", conditionMessage(e), "). Verifique conexão/fonte.\n") 
})

# Registro de proveniencia (auditoria)
attr(btc_raw, "fonte") <- FONTE_BTC
cat(sprintf(">>> BTC obtido de '%s': %d observações (%s a %s)\n",
            FONTE_BTC, nrow(btc_raw),
            format(min(index(btc_raw))), format(max(index(btc_raw)))))

# Sufixo de fonte para arquivos derivados de BTC (VIX nao recebe: fonte invariante)
SUF_FONTE <- paste0("_", FONTE_BTC)   # "_yahoo" ou "_cmc"

write_xts_xlsx(btc_raw, paste0("BTC", SUF_FONTE, ".xlsx"), out_dir)
write_xts_xlsx(vix_raw, "VIX.xlsx", out_dir)   # sem sufixo: sempre Yahoo

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

write_xts_xlsx(rets, paste0("ret_BTC_VIX_emLinha", SUF_FONTE, ".xlsx"), out_dir)

cat(sprintf(">>> Dados carregados (fonte BTC: %s). Amostra total: %d observações.\n",
            FONTE_BTC, nrow(rets)))