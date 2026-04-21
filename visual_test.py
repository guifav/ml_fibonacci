"""Render a few game states headlessly and save screenshots to /tmp/shots."""
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


# 1) Initial random board
game = main.Game(seed=7)
render(game)
save("01_initial.png")

# 2) Board with a selection highlight
game.selected = (3, 3)
render(game)
save("02_selected.png")
game.selected = None

# 3) Plant an isolated group of 5 and trigger the explosion mid-animation
for r in range(main.GRID_ROWS):
    for c in range(main.GRID_COLS):
        game.board[r][c] = main.Piece(2 if (r + c) % 2 == 0 else 3)
for c in range(5):
    game.board[4][c] = main.Piece(0)

groups = main.find_groups(game.board)
game.trigger_explosions(groups)

# Step through explosion animation
for i in range(6):
    game.update(1 / 60)
    render(game)
    save(f"03_explode_{i:02d}.png")

# Finish animation including fall + cascade
for _ in range(600):
    game.update(1 / 60)
    if game.state == "idle":
        break
render(game)
save("04_after_cascade.png")
print(f"final score: {game.score}")

pygame.quit()
