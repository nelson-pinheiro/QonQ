# =============================================================================
# 4. GRÁFICO DE PREÇOS (BTC E VIX) COM EIXO DUPLO
# =============================================================================
cat("\n>>> Gerando Gráfico de Preços (Eixo Duplo)...\n")

# Preparação dos dados para ggplot
df_prices_plot <- data.frame(Date = index(data_prices), coredata(data_prices))

# Cálculo do fator de escala para o segundo eixo (VIX)
# O objetivo é "esticar" o VIX para que ele ocupe um espaço visual similar ao BTC
scale_factor <- max(df_prices_plot$BTC) / max(df_prices_plot$VIX)

p_prices <- ggplot(df_prices_plot, aes(x = Date)) +
  # Linha do BTC (Eixo Y Primário - Esquerda)
  geom_line(aes(y = BTC, color = "Bitcoin (BTC)"), linewidth = 0.8) +
  
  # Linha do VIX (Eixo Y Secundário - Direita)
  # Multiplicamos o VIX pelo fator de escala para plotar
  geom_line(aes(y = VIX * scale_factor, color = "VIX Index"), linewidth = 0.8) +
  
  # Definição dos Eixos Y
  scale_y_continuous(
    name = "Preço Bitcoin (USD)", # Nome do eixo primário
    labels = scales::dollar_format(), # Formato de moeda
    # Definição do eixo secundário
    sec.axis = sec_axis(~ . / scale_factor, name = "VIX Index") # Divide pelo fator para mostrar o valor real
  ) +
  
  # Definição das Cores Manuais
  scale_color_manual(values = c("Bitcoin (BTC)" = "#2166ac", # Azul
                                "VIX Index" = "#b2182b")) + # Vermelho
  
  # Títulos e Tema
  labs(x = NULL, color = NULL,
       title = "Evolução de Bitcoin & VIX",
       subtitle = "Escalas Verticais Diferentes (Eixo Duplo)") +
  theme_minimal() +
  theme(legend.position = "bottom",
        axis.text.y.left = element_text(color = "#2166ac"), # Cor do texto do eixo BTC
        axis.title.y.left = element_text(color = "#2166ac"),
        axis.text.y.right = element_text(color = "#b2182b"), # Cor do texto do eixo VIX
        axis.title.y.right = element_text(color = "#b2182b")) +
  scale_x_date(date_labels = "%Y", date_breaks = "1 year")

# Exibição e Salvamento
print(p_prices)
ggsave("Resultados/Figuras/Precos_BTC_VIX_EixoDuplo.png", p_prices, width = 10, height = 6)

cat("   [OK] Gráfico de preços salvo em Resultados/Figuras/\n")
