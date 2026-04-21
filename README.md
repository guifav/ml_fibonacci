# Fibonacci Shells

Um jogo no estilo Candy Crush em que as peças são **conchas espirais** desenhadas proceduralmente e as explosões seguem a **sequência de Fibonacci** (3, 5, 8, 13, 21...).

## Regras

- Tabuleiro 8x8 com 6 cores de conchas.
- Clique em uma peça e depois em uma adjacente (vertical/horizontal) para trocá-las.
- Uma troca só é válida se gerar um grupo conectado de peças da mesma cor com tamanho **≥ 3**.
- Quando o grupo for exatamente um número da sequência de Fibonacci (3, 5, 8, 13, 21...), você ganha um **multiplicador exponencial** baseado no índice Fibonacci. Grupos de tamanho não-Fibonacci (4, 6, 7, 9...) ainda explodem, mas valem apenas a pontuação base do Fibonacci imediatamente inferior.
- Peças acima caem e novas peças surgem no topo, podendo gerar combos em cascata (cada cascata adiciona um multiplicador extra).

## Pontuação

| Tamanho | Nome      | Pontos base |
|---------|-----------|-------------|
| 3       | F₄        | 30          |
| 5       | F₅ ✨      | 80          |
| 8       | F₆ 🌟      | 210         |
| 13      | F₇ 💫      | 550         |
| 21      | F₈ 🌠      | 1440        |

Cascatas aumentam o multiplicador em +1x a cada nível.

## Como rodar

```bash
pip install -r requirements.txt
python main.py
```

## Controles

- **Clique** em uma peça para selecioná-la.
- **Clique** em uma peça adjacente para trocar.
- **R** para reiniciar o tabuleiro.
- **ESC** para sair.
