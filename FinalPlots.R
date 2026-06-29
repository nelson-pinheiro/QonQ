# =============================================================================
# 4. GRÁFICO DE PREÇOS (BTC E VIX) COM EIXO DUPLO
# =============================================================================
cat("\n>>> Gerando Gráfico de Preços (Eixo Duplo)...\n")

# Preparação dos dados para ggplot
df_prices_plot <- data.frame(Date = index(data_prices), coredata(data_prices))

# Cálculo do fator de escala para o segundo eixo (VIX)
# O objetivo é "esticar" o VIX para que ele ocupe um espaço visual similar ao cripto
scale_factor <- max(df_prices_plot[[CRYPTO_SYMBOL]]) / max(df_prices_plot$VIX)

crypto_legend_label <- paste0(CRYPTO_LABEL, " (", CRYPTO_SYMBOL, ")")

p_prices <- ggplot(df_prices_plot, aes(x = Date)) +
  # Linha do cripto (Eixo Y Primário - Esquerda)
  geom_line(aes(y = .data[[CRYPTO_SYMBOL]], color = crypto_legend_label), linewidth = 0.8) +

  # Linha do VIX (Eixo Y Secundário - Direita)
  # Multiplicamos o VIX pelo fator de escala para plotar
  geom_line(aes(y = VIX * scale_factor, color = "VIX Index"), linewidth = 0.8) +

  # Definição dos Eixos Y
  scale_y_continuous(
    name = paste0("Preço ", CRYPTO_LABEL, " (USD)"),
    labels = scales::dollar_format(),
    sec.axis = sec_axis(~ . / scale_factor, name = "VIX Index")
  ) +

  # Definição das Cores Manuais
  scale_color_manual(values = setNames(
    c("#2166ac", "#b2182b"),
    c(crypto_legend_label, "VIX Index")
  )) +

  # Títulos e Tema
  labs(x = NULL, color = NULL,
       title = paste0("Evolução de ", CRYPTO_LABEL, " & VIX"),
       subtitle = "Escalas Verticais Diferentes (Eixo Duplo)") +
  theme_minimal() +
  theme(legend.position = "bottom",
        axis.text.y.left = element_text(color = "#2166ac"), # Cor do texto do eixo BTC
        axis.title.y.left = element_text(color = "#2166ac"),
        axis.text.y.right = element_text(color = "#b2182b"), # Cor do texto do eixo VIX
        axis.title.y.right = element_text(color = "#b2182b")) +
  scale_x_date(date_labels = "%Y", date_breaks = "1 year")

# Fallback defensivo (caso o script rode isolado, sem LoadData.R antes)
if (!exists("SUF_FONTE")) SUF_FONTE <- ""

# Exibição e Salvamento
print(p_prices)
ggsave(file.path("Resultados/Figuras",
                 paste0("Precos_", CRYPTO_SYMBOL, "_VIX_EixoDuplo", SUF_FONTE, ".png")),
       p_prices, width = 10, height = 6)

cat("   [OK] Gráfico de preços salvo em Resultados/Figuras/\n")