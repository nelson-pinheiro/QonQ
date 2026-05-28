# QonQ — Codebase Guide for AI Assistants

## Project Overview

**QonQ** (Quantile-on-Quantile) is an empirical financial research project implementing a
Quantile Vector Autoregression (QVAR) connectedness analysis between Bitcoin (BTC-USD) returns
and the VIX Volatility Index. The analysis examines how risk-transmission between Bitcoin and
traditional market fear gauges changed after the Bitcoin Spot ETF approval on **January 11, 2024**.

This is a dissertation research codebase, not production software. The workflow is
script-based and sequential; there is no web server, no API, and no automated test suite.

The accompanying dissertation is:
> *"Bitcoin e Regimes de Aversão ao Risco: Uma Análise de Conectividade Quantil-Sobre-Quantil"*

---

## Repository Structure

The repository is intentionally flat — all source files live at the root.

```
qonq/
├── main.R                      # Master entry point; orchestrates full pipeline
├── LoadPackages.R              # Dependency validation and loading
├── LoadData.R                  # Data download, cleaning, and period splitting
├── MakeFirstStatistics.R       # Descriptive stats + stationarity tests on prices
├── MakeStatistics.R            # Same stats on log-returns (used in model diagnostics)
├── Models.R                    # Core QVAR engine; all quantile-loop computation
├── FinalPlots.R                # Dual-axis BTC/VIX price evolution chart
├── GeraDistribuição.py         # Return distribution plots (Python, standalone)
├── .Rprofile                   # Activates renv on session start
├── Code.Rproj                  # RStudio project file (project name: QonQ)
├── Dissertação Nelson 1.04.pdf # Dissertation document
└── Resultados/                 # Generated at runtime (not tracked in git)
    ├── Figuras/                # All PNG charts
    ├── Tabelas/                # Excel workbooks (.xlsx)
    ├── Dados/                  # Raw data exports
    └── Robustez/               # Sensitivity/robustness outputs
```

---

## Running the Project

### Prerequisites

- **R** ≥ 4.2 with the `renv` package installed
- **RStudio** (recommended) or any R-compatible terminal
- **Python** ≥ 3.9 with `matplotlib`, `scipy`, `numpy`, `pandas` (for `GeraDistribuição.py` only)

### R Workflow

1. Open `Code.Rproj` in RStudio (or set working directory to repo root).
2. The `.Rprofile` automatically activates the `renv` environment on session start.
3. On first run, restore locked package versions:
   ```r
   renv::restore()
   ```
4. Run the full pipeline:
   ```r
   source("main.R")
   ```
   This takes **several minutes** (the QVAR loop is compute-intensive).

To run individual stages in isolation:
```r
source("LoadPackages.R")       # Always run first
source("LoadData.R")
source("MakeFirstStatistics.R")
source("MakeStatistics.R")
source("Models.R")             # Long-running
source("FinalPlots.R")
```

### Python Script (standalone)

```bash
python GeraDistribuição.py
```

This script is independent of the R pipeline. It reads no shared state; all data
is fetched internally via `yfinance` or from the `Resultados/Dados/` exports.

---

## Key Parameters

These are the central tuning knobs in the analysis. When modifying them, update
consistently across all files that reference them.

| Parameter | Value | Location | Purpose |
|---|---|---|---|
| `split_date` | `as.Date("2024-01-11")` | `LoadData.R` | BTC Spot ETF approval cutoff |
| `window_size` | `200` | `Models.R` | Rolling window for VAR estimation (trading days) |
| `forecast_horizon` | `20` | `Models.R` | Forecast horizon for connectedness (trading days) |
| Quantile grid | `seq(0.05, 0.95, by = 0.10)` | `Models.R` | 10 quantile levels for QVAR |
| Data start | `"2014-09-17"` | `LoadData.R` | Earliest BTC data on Yahoo Finance |
| Data end | `Sys.Date()` (dynamic) | `LoadData.R` | Always fetches up to today |

The quantile loop runs 10×10 = 100 QVAR estimations per rolling window step, making
`Models.R` the computational bottleneck. The 3D output tensor is shaped
`[time_steps, 10, 10]` (indexed by `[t, quantile_i, quantile_j]`).

---

## Code Conventions

### Language

All variable names, comments, and inline documentation are in **Portuguese**, matching
the dissertation language. Follow this convention when adding or modifying code.

```r
# Correto
retornos_btc <- diff(log(dados_btc))

# Evitar
btc_returns <- diff(log(btc_data))
```

### Output File Naming

Output filenames encode all critical parameters to ensure reproducibility and avoid
accidental overwrites. The pattern is:

```
<METRIC>_<TYPE>_W<window>_H<horizon>_<PERIOD>.<ext>
```

Examples:
- `TCI_HEATMAP_W200_H20_PRE_ETF.png`
- `NET_SPILLOVERS_20250101_20260131_POST_ETF_W200_H20.xlsx`

Always follow this pattern when adding new outputs.

### Color Scheme

Use these colors consistently across all ggplot2 and base-R charts:

| Meaning | Hex | Usage |
|---|---|---|
| BTC / positive values | `#2166ac` (blue) | Bitcoin lines, positive spillovers |
| VIX / negative values | `#b2182b` (red) | VIX lines, negative spillovers |
| Neutral / baseline | `#000000` (black) | Reference lines, full-sample metrics |

### Temporal Comparisons

Always wrap date literals in `as.Date()`:
```r
# Correto
data_split <- as.Date("2024-01-11")
dados_pre <- subset(dados, date < data_split)

# Evitar — implicit coercion can cause silent bugs
dados_pre <- subset(dados, date < "2024-01-11")
```

### Output Directories

All generated files go under `Resultados/`. `main.R` creates these directories at
startup; individual scripts may also create them. Never write output to the repo root.

```r
dir.create("Resultados/Figuras", recursive = TRUE, showWarnings = FALSE)
```

### Error Handling in Models.R

The QVAR estimation loop uses `tryCatch` to handle non-convergence gracefully.
Increment the failure counter (`falhas`) rather than letting errors propagate:

```r
resultado <- tryCatch({
  connectedness_func(...)
}, error = function(e) {
  falhas <<- falhas + 1
  NULL
})
```

---

## Dependency Management

### R — renv

Package versions are locked in `renv.lock`. The `.Rprofile` sources `renv/activate.R`
automatically. **Do not install packages with `install.packages()` directly** — use
`renv::install()` to keep the lockfile in sync.

Core packages and their roles:

| Package | Role |
|---|---|
| `ConnectednessApproach` | QVAR estimation and connectedness decomposition |
| `quantmod` / `TTR` / `xts` | Financial time series download and manipulation |
| `ggplot2` / `gridExtra` / `RColorBrewer` | Publication-quality visualization |
| `tseries` / `FinTS` | ADF, ARCH-LM, and other diagnostic tests |
| `moments` | Skewness and kurtosis computation |
| `openxlsx` | Excel export with multiple sheets |
| `lubridate` | Date arithmetic |

### Python

No lock file is maintained for Python. The script uses standard scientific stack:
`matplotlib`, `scipy`, `numpy`, `pandas`. Install manually or via pip:

```bash
pip install matplotlib scipy numpy pandas yfinance
```

---

## Data Flow

```
Yahoo Finance (quantmod::getSymbols)
       │
       ▼
  LoadData.R ─── exports raw prices to Resultados/Dados/
       │
       ├─► dados_btc_retornos  (log returns, full sample)
       ├─► dados_vix_retornos
       ├─► dados_pre_etf       (before 2024-01-11)
       └─► dados_pos_etf       (after  2024-01-11)
              │
              ▼
  MakeFirstStatistics.R / MakeStatistics.R
              │  (descriptive stats, stationarity tests)
              ▼
          Models.R
              │  (QVAR loop → 3D tensor TCI_3D[t, qi, qj])
              ├─► Static heatmaps  → Resultados/Figuras/
              ├─► Dynamic TCI      → Resultados/Figuras/
              └─► NET/TCI tables   → Resultados/Tabelas/
              │
              ▼
         FinalPlots.R
              │  (BTC vs VIX price chart)
              └─► Resultados/Figuras/
```

---

## Analysis Periods

The analysis splits data into three periods:

| Period | Date Range | Purpose |
|---|---|---|
| Full Sample | 2014-09-17 → present | Baseline connectedness |
| Pre-ETF | 2014-09-17 → 2024-01-10 | Pre-approval regime |
| Post-ETF | 2024-01-11 → present | Post-approval regime |

Excel outputs always include three sheets corresponding to these periods.

---

## Branch Strategy

| Branch | Purpose |
|---|---|
| `main` | Stable, dissertation-ready code |
| `Testes-extras-de-Robustez` | Sensitivity tests with alternative window sizes and horizons |

Commits use simple, descriptive messages (no conventional-commits convention enforced).

---

## What This Project Does NOT Have

AI assistants should not expect or add:
- Automated tests (no `testthat`, no pytest)
- CI/CD pipelines (no `.github/workflows/`)
- Linting configuration (no lintr, no ruff)
- A Makefile or task runner
- Modular package structure (no `R/` package layout)
- A web interface or API layer
