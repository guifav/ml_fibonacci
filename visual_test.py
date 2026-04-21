"""Render several states showcasing the charged-glow mechanic."""
import os
import pathlib

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame  # noqa: E402

pygame.init()

import main  # noqa: E402

OUT = pathlib.Path("/tmp/shots")
OUT.mkdir(exist_ok=True)

screen = pygame.display.set_mode((main.WINDOW_W, main.WINDOW_H))
font = pygame.font.SysFont("dejavusans", 18)
small = pygame.font.SysFont("dejavusans", 14)
big = pygame.font.SysFont("dejavusans", 26, bold=True)


def render(game: main.Game) -> None:
    main.draw_background(screen)
    main.draw_board(screen, game, main.BOARD_MARGIN, main.BOARD_MARGIN)
    main.draw_sidebar(
        screen, game,
        main.BOARD_MARGIN + main.BOARD_W + main.BOARD_MARGIN,
        main.BOARD_MARGIN,
        font, small, big,
    )


def save(name: str) -> None:
    path = OUT / name
    pygame.image.save(screen, str(path))
    print(f"saved {path}")


# Build a board with two charged groups of sizes 3 and 5
game = main.Game(seed=7)
for r in range(main.GRID_ROWS):
    for c in range(main.GRID_COLS):
        game.board[r][c] = main.Piece(2 if (r + c) % 2 == 0 else 3)
for c in range(3):
    game.board[1][c] = main.Piece(0)
for c in range(5):
    game.board[4][c] = main.Piece(1)
main.recompute_charges(game.board)

render(game)
save("10_charged.png")

# Detonate the 5-group
game.on_click(4, 2, button=3)
for i in range(5):
    game.update(1 / 60)
render(game)
save("11_detonating.png")

# Finish animation
for _ in range(600):
    game.update(1 / 60)
    if game.state == "idle":
        break
render(game)
save("12_post_cascade.png")
print(f"final score: {game.score}, combo_level: {game.combo_level}")

pygame.quit()
