# =============================================================================
# CARREGAMENTO DE PACOTES (reprodutível com renv)
# =============================================================================
# Lista de pacotes necessários
packages <- c(
  "devtools", "zoo", "xts", "quantmod", "TTR",
  "ConnectednessApproach", "tseries", "moments",
  "openxlsx", "ggplot2", "reshape2", "lubridate",
  "timeDate", "RColorBrewer", "gridExtra", "scales", 
  "FinTS", "rprojroot", "crypto2"
)

missing <- setdiff(packages, rownames(installed.packages()))

if (length(missing) > 0) {
  stop(
    "Pacotes ausentes no ambiente do projeto (renv): ",
    paste(missing, collapse = ", "),
    "\n\nComo corrigir (no Console, com o projeto aberto):",
    "\n  install.packages(c(", paste(sprintf('"%s"', missing), collapse = ", "), "))",
    "\n  renv::snapshot()",
    call. = FALSE
  )
}

# Falha cedo se não carregar
for (p in packages) {
  suppressPackageStartupMessages(
    library(p, character.only = TRUE)
  )
}