import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
from scipy.stats import skew, kurtosis

# =============================================================================
# 1. CONFIGURAÇÃO E CARREGAMENTO DE DADOS
# =============================================================================
# Carregar dados brutos (assumindo que já são retornos conforme snippet visualizado)
file_path = 'rets_BTC_VIX.csv'

# Ajuste para ler separador decimal vírgula e delimitador ponto-e-vírgula
df = pd.read_csv(file_path, sep=';', decimal=',')

# Converter data
df['Date'] = pd.to_datetime(df['Date'], format='%d/%m/%Y')
df = df.set_index('Date').sort_index()

# Filtrar apenas BTC e garantir numérico
df = df[['BTC']].apply(pd.to_numeric, errors='coerce').dropna()

# =============================================================================
# 2. DEFINIÇÃO DOS PERÍODOS (Seguindo a Dissertação 0.4)
# =============================================================================
# Data de corte do ETF (SEC Approval)
etf_approval_date = '2024-01-10'

# Criar subconjuntos
periods = {
    "Amostra Total (Full Sample)": df['BTC'],
    "Pré-ETF (até Jan/2024)": df.loc[df.index <= etf_approval_date, 'BTC'],
    "Pós-ETF (após Jan/2024)": df.loc[df.index > etf_approval_date, 'BTC']
}

# =============================================================================
# 3. CÁLCULO DE LIMITES GLOBAIS (Para garantir "Mesma Escala")
# =============================================================================
# Definir limites fixos para os eixos baseados no extremo de toda a amostra
# Adiciona uma margem de 10% para estética
global_min_x = df['BTC'].min()
global_max_x = df['BTC'].max()
xlims = (global_min_x * 1.1, global_max_x * 1.1)

# Para o eixo Y (Frequência/Densidade), precisamos estimar o máximo da densidade
# Vamos deixar o Y um pouco flexível ou fixar baseado no pico máximo observado
# Opção: Fixar apenas X rigorosamente, pois Y depende da quantidade de bins/densidade

# =============================================================================
# 4. PLOTAGEM EMPILHADA (STACKED)
# =============================================================================
fig, axes = plt.subplots(3, 1, figsize=(10, 12), sharex=True, sharey=True)
plt.subplots_adjust(hspace=0.15) # Espaço pequeno entre gráficos

colors = ['#2c3e50', '#e74c3c', '#27ae60'] # Cores sóbrias acadêmicas

for ax, (label, data), color in zip(axes, periods.items(), colors):
    # Estatísticas Descritivas para Anotação
    mu = data.mean()
    sigma = data.std()
    sk = skew(data)
    ku = kurtosis(data) # Fisher (excesso de curtose, normal = 0) ou Pearson?
    # Usaremos Pearson normalizado (Normal = 3) para facilitar leitura acadêmica tradicional
    # Scipy kurtosis é Fisher (Normal = 0). Vamos ajustar para Pearson somando 3 se necessário,
    # mas manteremos Fisher indicando "Excesso de Curtose" que é padrão em softwares como R/Eviews.
    
    # Histograma
    sns.histplot(data, ax=ax, stat='density', bins=50, 
                 color=color, alpha=0.6, edgecolor='white', linewidth=0.5, label='Histograma')
    
    # KDE (Kernel Density Estimate) - Linha Suave
    sns.kdeplot(data, ax=ax, color='black', linewidth=1.5, label='Densidade (KDE)')
    
    # Linhas de referência
    ax.axvline(0, color='black', linestyle='--', linewidth=0.8, alpha=0.5)
    
    # Texto com Estatísticas (Box no canto superior)
    stats_text = (f"Obs: {len(data)}\n"
                  f"Média: {mu:.4f}\n"
                  f"Desvio Padrão: {sigma:.4f}\n"
                  f"Assimetria: {sk:.4f}\n"
                  f"Curtose (Excesso): {ku:.4f}")
    
    ax.text(0.98, 0.95, stats_text, transform=ax.transAxes, 
            verticalalignment='top', horizontalalignment='right',
            bbox=dict(boxstyle='round', facecolor='white', alpha=0.9),
            fontsize=9)

    # Títulos e Labels
    ax.set_title(label, fontsize=12, fontweight='bold', loc='left')
    ax.set_ylabel("Densidade", fontsize=10)
    ax.grid(True, which='major', axis='y', linestyle=':', alpha=0.6)

# Ajuste final do eixo X comum
axes[2].set_xlabel("Retornos Logarítmicos do Bitcoin (%)", fontsize=11)
plt.xlim(xlims) # Força a mesma escala visual horizontal

# Título Geral (Opcional, pode ser removido para documento ABNT)
# plt.suptitle("Distribuição Incondicional dos Retornos do Bitcoin", fontsize=14)

plt.tight_layout()

# Salvar
output_filename = "Distribuicao_Retornos_BTC_Periodos.png"
plt.savefig(output_filename, dpi=300, bbox_inches='tight')
print(f"Gráfico gerado com sucesso: {output_filename}")

plt.show()
