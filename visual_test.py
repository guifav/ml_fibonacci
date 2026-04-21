"""Render screenshots showcasing timer, charged clusters, game-over screen."""
import os
import pathlib
import tempfile
from pathlib import Path

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame  # noqa: E402

pygame.init()

import main  # noqa: E402

# Use an isolated leaderboard file so we don't pollute anything
TMP_SCORES = Path(tempfile.mkstemp(suffix="-scores.json")[1])
TMP_SCORES.unlink(missing_ok=True)
main.SCORES_PATH = TMP_SCORES

OUT = pathlib.Path("/tmp/shots")
OUT.mkdir(exist_ok=True)

screen = pygame.display.set_mode((main.WINDOW_W, main.WINDOW_H))
font = pygame.font.SysFont("dejavusans", 18)
small = pygame.font.SysFont("dejavusans", 14)
big = pygame.font.SysFont("dejavusans", 26, bold=True)


def render(game: main.Game) -> None:
    main.draw_background(screen)
    main.draw_board(screen, game, main.BOARD_MARGIN, main.BOARD_MARGIN)
    if game.state == "gameover":
        main.draw_game_over(screen, game, main.BOARD_MARGIN, main.BOARD_MARGIN, font, small, big)
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


# Seed a leaderboard with a couple of previous entries
main.save_scores([
    {"score": 820, "best_tier": 8, "date": "2026-04-21T14:10:00"},
    {"score": 540, "best_tier": 5, "date": "2026-04-20T20:55:00"},
])

# Fresh game; tweak timer and plant groups
game = main.Game(seed=7)
game.time_left = 67.0
for r in range(main.GRID_ROWS):
    for c in range(main.GRID_COLS):
        game.board[r][c] = main.Piece(2 if (r + c) % 2 == 0 else 3)
for c in range(3):
    game.board[1][c] = main.Piece(0)
for c in range(5):
    game.board[4][c] = main.Piece(1)
main.recompute_charges(game.board)

render(game)
save("20_playing.png")

# Urgent timer
game.time_left = 9.0
render(game)
save("21_urgent_timer.png")

# Detonate, finish animations, force game over
game.time_left = 40.0
game.on_click(4, 2, button=3)
for _ in range(200):
    game.update(1 / 60)
    if game.state == "idle":
        break
# Now expire the timer
game.time_left = 0.01
game.update(0.02)
render(game)
save("22_game_over.png")
print(f"final score: {game.score}, rank: {game.last_rank}")

TMP_SCORES.unlink(missing_ok=True)
pygame.quit()
