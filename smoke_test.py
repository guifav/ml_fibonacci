"""Headless smoke test — runs the game loop for a few frames with a scripted
swap to exercise match detection, explosions and cascade refill without opening
a display."""
import os
os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame  # noqa: E402

pygame.init()
pygame.display.set_mode((1, 1))

import main  # noqa: E402


def force_match(game: main.Game) -> None:
    # Paint everything with alternating checkerboard of two "background" colors
    # (2 and 3) so the forced 0/1 groups below are isolated from each other.
    for r in range(main.GRID_ROWS):
        for c in range(main.GRID_COLS):
            game.board[r][c] = main.Piece(2 if (r + c) % 2 == 0 else 3)
    # Plant a guaranteed horizontal match of 3 at row 0
    for c in range(3):
        game.board[0][c] = main.Piece(0)
    # Sanity buffer so the row-2 group doesn't touch the row-0 group
    # And a group of exactly 5 (Fibonacci exact) at row 2
    for c in range(5):
        game.board[2][c] = main.Piece(1)


def main_test() -> None:
    game = main.Game(seed=42)
    force_match(game)
    # Drive the state machine: trigger detection by pretending a swap resolved
    groups = main.find_groups(game.board)
    assert any(len(g) == 3 for g in groups), "expected a group of 3"
    assert any(len(g) == 5 for g in groups), "expected a group of 5"
    print(f"initial groups sizes = {[len(g) for g in groups]}")

    game.trigger_explosions(groups)
    assert game.state == "explode"
    assert game.score > 0
    print(f"score after explosions: {game.score}")

    # Advance frames until state returns to idle
    max_frames = 600
    for _ in range(max_frames):
        game.update(1 / 60)
        if game.state == "idle":
            break
    else:
        raise SystemExit("game never settled back to idle")

    # Sanity: grid is full, no -1 colors
    for r in range(main.GRID_ROWS):
        for c in range(main.GRID_COLS):
            assert game.board[r][c].color >= 0, f"empty cell left at {r},{c}"

    # Render once to make sure draw functions don't crash
    screen = pygame.display.get_surface()
    font = pygame.font.SysFont(None, 18)
    small = pygame.font.SysFont(None, 14)
    big = pygame.font.SysFont(None, 26)
    main.draw_background(screen)
    main.draw_board(screen, game, 10, 10)
    main.draw_sidebar(screen, game, 10, 10, font, small, big)
    print("smoke OK; final score =", game.score)


if __name__ == "__main__":
    main_test()
    pygame.quit()
