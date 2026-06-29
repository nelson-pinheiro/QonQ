# =============================================================================
# CARREGAMENTO DE DADOS
# =============================================================================

cat(">>> Carregando dados...\n")

# -----------------------------------------------------------------------------
# CONFIGURAÇÃO DO ATIVO CRIPTO (editável)
#   CRYPTO_SYMBOL   : símbolo do ativo usado em nomes de coluna e arquivos
#                     Ex: "BTC", "ETH", "SOL", "BNB"
#   CRYPTO_CMC_SLUG : slug no CoinMarketCap (usado quando FONTE_CRYPTO="cmc")
#                     Ex: "bitcoin", "ethereum", "solana", "binancecoin"
#   CRYPTO_YAHOO    : ticker no Yahoo Finance (usado quando FONTE_CRYPTO="yahoo")
#                     Ex: "BTC-USD", "ETH-USD", "SOL-USD", "BNB-USD"
#   CRYPTO_LABEL    : nome por extenso para títulos de gráficos
#                     Ex: "Bitcoin", "Ethereum", "Solana"
# -----------------------------------------------------------------------------
CRYPTO_SYMBOL   <- "BTC"
CRYPTO_CMC_SLUG <- "bitcoin"
CRYPTO_YAHOO    <- "BTC-USD"
CRYPTO_LABEL    <- "Bitcoin"

# -----------------------------------------------------------------------------
# CONFIGURAÇÃO DE FONTE (editável)
#   "yahoo" -> getSymbols via quantmod
#   "cmc"   -> CoinMarketCap via pacote crypto2
# Observação: o VIX SEMPRE vem do Yahoo (índice CBOE, indisponível no CMC).
# -----------------------------------------------------------------------------
FONTE_CRYPTO <- "cmc"   # alterne entre "yahoo" e "cmc"

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
# Função: obtém cripto via CoinMarketCap (crypto2) e devolve xts no formato
# OHLCV compatível com o objeto retornado por quantmod::getSymbols.
# -----------------------------------------------------------------------------
get_crypto_cmc <- function(from, to, slug = CRYPTO_CMC_SLUG, symbol = CRYPTO_SYMBOL) {
  if (!requireNamespace("crypto2", quietly = TRUE)) {
    stop("Pacote 'crypto2' ausente. Instale com install.packages('crypto2') e rode renv::snapshot().",
         call. = FALSE)
  }

  moedas  <- crypto2::crypto_list(only_active = TRUE)
  coin    <- moedas[moedas$slug == slug, , drop = FALSE]
  stopifnot(paste0(symbol, " (slug='", slug, "') nao encontrado no catalogo CMC") = nrow(coin) == 1L)

  hist <- crypto2::crypto_history(
    coin_list  = coin,
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
  colnames(x) <- paste0(symbol, ".", colnames(x))  # ex: BTC.Open, ETH.Close ...
  x <- x[!duplicated(zoo::index(x)), ]
  xts::xts(x, order.by = zoo::index(x))
}

# Download
tryCatch({
  if (identical(FONTE_CRYPTO, "yahoo")) {
    cat(sprintf(">>> Fonte %s: Yahoo Finance (getSymbols '%s')\n", CRYPTO_SYMBOL, CRYPTO_YAHOO))
    crypto_raw <- getSymbols(CRYPTO_YAHOO, src = "yahoo", from = start_date, to = end_date, auto.assign = FALSE)
  } else if (identical(FONTE_CRYPTO, "cmc")) {
    cat(sprintf(">>> Fonte %s: CoinMarketCap (crypto2, slug='%s')\n", CRYPTO_SYMBOL, CRYPTO_CMC_SLUG))
    crypto_raw <- get_crypto_cmc(from = start_date, to = end_date,
                                 slug = CRYPTO_CMC_SLUG, symbol = CRYPTO_SYMBOL)
  } else {
    stop("FONTE_CRYPTO invalida: use 'yahoo' ou 'cmc'.", call. = FALSE)
  }

  # VIX sempre via Yahoo (indice CBOE, indisponivel no CMC)
  vix_raw <- getSymbols("^VIX", src = "yahoo", from = start_date, to = end_date, auto.assign = FALSE)
}, error=function(e) {
  stop("\nErro crítico: Falha no download (", conditionMessage(e), "). Verifique conexão/fonte.\n")
})

# Registro de proveniencia (auditoria)
attr(crypto_raw, "fonte") <- FONTE_CRYPTO
cat(sprintf(">>> %s obtido de '%s': %d observações (%s a %s)\n",
            CRYPTO_SYMBOL, FONTE_CRYPTO, nrow(crypto_raw),
            format(min(index(crypto_raw))), format(max(index(crypto_raw)))))

# Sufixo de fonte para arquivos derivados do cripto (VIX nao recebe: fonte invariante)
SUF_FONTE <- paste0("_", FONTE_CRYPTO)   # "_yahoo" ou "_cmc"

write_xts_xlsx(crypto_raw, paste0(CRYPTO_SYMBOL, SUF_FONTE, ".xlsx"), out_dir)
write_xts_xlsx(vix_raw, "VIX.xlsx", out_dir)   # sem sufixo: sempre Yahoo

# Tratamento e Retornos
crypto_close <- Ad(crypto_raw)
vix_close    <- Ad(vix_raw)

# Merge (Garante alinhamento temporal)
data_merged <- merge(crypto_close, vix_close, join = "inner")
colnames(data_merged) <- c(CRYPTO_SYMBOL, "VIX")
data_prices <- na.omit(data_merged)

rets <- data_prices
rets[[CRYPTO_SYMBOL]] <- diff(log(data_prices[[CRYPTO_SYMBOL]])) * 100

# Retornos Logarítmicos (VARIÁVEL BASE DO MODELO)
rets <- na.omit(rets)
NAMES <- colnames(rets)

write_xts_xlsx(rets, paste0("ret_", CRYPTO_SYMBOL, "_VIX_emLinha", SUF_FONTE, ".xlsx"), out_dir)

cat(sprintf(">>> Dados carregados (fonte %s: %s). Amostra total: %d observações.\n",
            CRYPTO_SYMBOL, FONTE_CRYPTO, nrow(rets)))