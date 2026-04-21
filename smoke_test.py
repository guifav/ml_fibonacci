"""Headless smoke test for charged/detonation mechanic, timer and leaderboard.

Points verified:
- Charge recomputation after swaps
- Right-click detonation + combo multiplier
- Countdown timer triggers game over
- Score recorded to leaderboard (isolated to a temp file)
"""
import os
import tempfile
from pathlib import Path

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame  # noqa: E402

pygame.init()
pygame.display.set_mode((1, 1))

import main  # noqa: E402

# Isolate leaderboard file so the test never touches the player's scores.json
TMP_SCORES = Path(tempfile.mkstemp(suffix="-scores.json")[1])
TMP_SCORES.unlink(missing_ok=True)
main.SCORES_PATH = TMP_SCORES


def plant_isolated_groups(game: main.Game) -> None:
    for r in range(main.GRID_ROWS):
        for c in range(main.GRID_COLS):
            game.board[r][c] = main.Piece(2 if (r + c) % 2 == 0 else 3)
    for c in range(3):
        game.board[0][c] = main.Piece(0)
    for c in range(5):
        game.board[2][c] = main.Piece(1)


def main_test() -> None:
    game = main.Game(seed=42)
    plant_isolated_groups(game)
    main.recompute_charges(game.board)
    assert game.board[0][0].charged and game.board[2][0].charged

    # Detonate size-3: score 60 (30 * 2 exact * 1 combo)
    game.on_click(0, 1, button=3)
    for _ in range(600):
        game.update(1 / 60)
        if game.state == "idle":
            break
    assert game.score == 60, f"expected 60 after first detonation, got {game.score}"
    assert game.best_tier_this_game == 3

    # Detonate size-5: combo x2 now → 80*2*2 = 320 → total 380
    game.on_click(2, 2, button=3)
    for _ in range(600):
        game.update(1 / 60)
        if game.state == "idle":
            break
    assert game.score == 380, f"expected 380, got {game.score}"
    assert game.best_tier_this_game == 5

    # 3) Force-expire the timer → game over + leaderboard entry
    game.time_left = 0.01
    game.update(0.02)
    assert game.state == "gameover", f"expected gameover, got {game.state}"
    assert game.last_rank == 0, f"expected rank 0, got {game.last_rank}"
    assert TMP_SCORES.exists(), "scores.json was not written"

    # Reload leaderboard via a fresh Game instance and verify persistence
    game2 = main.Game(seed=1)
    assert game2.leaderboard and game2.leaderboard[0]["score"] == 380
    assert game2.time_left == main.GAME_DURATION
    print(f"persisted top score: {game2.leaderboard[0]['score']}")

    # 4) Clicks after game over are ignored
    before_score = game.score
    game.on_click(0, 0, button=3)
    game.on_click(0, 0, button=1)
    assert game.score == before_score, "clicks should be ignored in game over"

    # 5) Render game over screen does not crash
    screen = pygame.display.get_surface()
    font = pygame.font.SysFont(None, 18)
    small = pygame.font.SysFont(None, 14)
    big = pygame.font.SysFont(None, 26)
    main.draw_background(screen)
    main.draw_board(screen, game, 10, 10)
    main.draw_game_over(screen, game, 10, 10, font, small, big)
    main.draw_sidebar(screen, game, 10, 10, font, small, big)
    print("smoke OK")


if __name__ == "__main__":
    try:
        main_test()
    finally:
        TMP_SCORES.unlink(missing_ok=True)
        pygame.quit()
