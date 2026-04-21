# Fibonacci Shells

Um jogo no estilo Candy Crush em que as peças são **conchas espirais** desenhadas proceduralmente e as explosões seguem a **sequência de Fibonacci** (3, 5, 8, 13, 21...).

## Regras

- Tabuleiro 8×8 com 6 cores de conchas.
- **Clique esquerdo**: seleciona uma peça, depois clique numa adjacente para **trocar**. A troca só é aceita se formar (ou aumentar) um grupo conectado de mesma cor com pelo menos 3 peças numa linha reta.
- Quando um grupo elegível existe, as peças **ficam carregadas** — um halo dourado pulsa em volta delas. **Elas não explodem sozinhas.**
- **Clique direito** numa peça carregada detona **aquele cluster** no tamanho atual. Cresça o cluster com novas trocas para atingir um número Fibonacci (**3 → 5 → 8 → 13 → 21…**) antes de detonar.
- Tamanhos exatamente Fibonacci ganham **bônus 2x**. Tamanhos intermediários (4, 6, 7, 9…) caem ao tier Fibonacci inferior.
- **Combo multiplier**: cada detonação sem uma nova troca entre elas adiciona **+1x** ao multiplicador. Trocar reseta o combo.
- Depois da detonação, peças caem e são substituídas do topo. Matches formados pela cascata também ficam carregados (você escolhe quando detonar).
- **Temporizador**: cada partida dura **90 segundos**. Quando o tempo acaba, a pontuação é salva no ranking local.
- **Ranking local**: top 10 pontuações persistem em `scores.json` (ao lado do `main.py`). Top 3 aparecem na sidebar; top 10 completo na tela de fim de jogo, com destaque na sua posição.

## Pontuação

| Tamanho | Nome      | Pontos base |
|---------|-----------|-------------|
| 3       | F₄        | 30          |
| 5       | F₅ ✨      | 80          |
| 8       | F₆ 🌟      | 210         |
| 13      | F₇ 💫      | 550         |
| 21      | F₈ 🌠      | 1440        |

Pontos = base × (2 se Fibonacci exato, 1 caso contrário) × (combo level + 1).

## Como rodar

Recomendado usar um ambiente virtual (especialmente no macOS com Homebrew Python, que bloqueia `pip install` no sistema):

```bash
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python main.py
```

Nas próximas execuções basta ativar o venv e rodar `python main.py`.

> O projeto usa `pygame-ce` (drop-in para `pygame`) para compatibilidade com Python 3.14. Se você já tinha `pygame` instalado no venv, rode `pip uninstall -y pygame && pip install -r requirements.txt`.

## Controles

- **Clique esquerdo** em uma peça para selecioná-la; clique em uma adjacente para trocar.
- **Clique direito** numa peça com halo dourado para detonar o cluster.
- **R** reinicia o tabuleiro, **ESC** sai.
