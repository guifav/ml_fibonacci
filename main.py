"""Fibonacci Shells - a Candy-Crush style game where matches follow Fibonacci.

Run with: python main.py
"""
from __future__ import annotations

import math
import random
import sys
from dataclasses import dataclass
from typing import Iterable

import pygame

# ---------- Configuration ----------
GRID_COLS = 8
GRID_ROWS = 8
CELL = 64
BOARD_MARGIN = 24
SIDEBAR_W = 260

BOARD_W = GRID_COLS * CELL
BOARD_H = GRID_ROWS * CELL
WINDOW_W = BOARD_W + SIDEBAR_W + BOARD_MARGIN * 3
WINDOW_H = BOARD_H + BOARD_MARGIN * 2

FPS = 60

# Visual palette — shell colors (base, highlight, shadow)
SHELL_COLORS: list[tuple[tuple[int, int, int], tuple[int, int, int], tuple[int, int, int]]] = [
    ((228, 92, 92),   (255, 170, 170), (150, 40, 40)),    # coral
    ((70, 140, 220),  (170, 210, 255), (30, 80, 150)),    # ocean
    ((240, 196, 80),  (255, 235, 170), (160, 110, 20)),   # sand
    ((160, 90, 200),  (220, 180, 245), (90, 40, 130)),    # purple
    ((240, 130, 180), (255, 200, 225), (170, 60, 110)),   # pink
    ((80, 180, 150),  (180, 230, 210), (30, 110, 90)),    # teal
]
NUM_COLORS = len(SHELL_COLORS)

BG_TOP = (20, 30, 55)
BG_BOTTOM = (10, 15, 30)
GRID_LINE = (255, 255, 255, 18)
PANEL_BG = (25, 35, 60)
PANEL_BORDER = (90, 120, 180)
TEXT_COLOR = (235, 235, 245)
TEXT_DIM = (160, 170, 200)
HIGHLIGHT = (255, 230, 120)

# Fibonacci sequence values used as "match tiers". We want F_4=3 onwards.
FIB_SIZES = [3, 5, 8, 13, 21, 34, 55]
# Base points per Fibonacci tier (grows faster than linear so bigger combos feel big)
FIB_POINTS = {3: 30, 5: 80, 8: 210, 13: 550, 21: 1440, 34: 3780, 55: 9900}
FIB_LABELS = {3: "F₄", 5: "F₅", 8: "F₆", 13: "F₇", 21: "F₈", 34: "F₉", 55: "F₁₀"}


def fib_tier(size: int) -> int:
    """Return the largest Fibonacci tier <= size, or 0 if below 3."""
    tier = 0
    for f in FIB_SIZES:
        if f <= size:
            tier = f
        else:
            break
    return tier


def is_fib(size: int) -> bool:
    return size in FIB_SIZES


# ---------- Shell rendering (procedural) ----------
_shell_cache: dict[tuple[int, int], pygame.Surface] = {}


def render_shell(color_idx: int, size: int = CELL) -> pygame.Surface:
    key = (color_idx, size)
    if key in _shell_cache:
        return _shell_cache[key]

    base, hi, sh = SHELL_COLORS[color_idx]
    surf = pygame.Surface((size, size), pygame.SRCALPHA)
    cx, cy = size / 2, size / 2
    radius = size * 0.42

    # Soft shadow
    shadow = pygame.Surface((size, size), pygame.SRCALPHA)
    pygame.draw.circle(shadow, (0, 0, 0, 90), (int(cx + 2), int(cy + 4)), int(radius))
    surf.blit(shadow, (0, 0))

    # Body
    pygame.draw.circle(surf, base, (int(cx), int(cy)), int(radius))
    # Rim
    pygame.draw.circle(surf, sh, (int(cx), int(cy)), int(radius), 2)
    # Highlight
    pygame.draw.circle(surf, hi, (int(cx - radius * 0.35), int(cy - radius * 0.4)), int(radius * 0.22))

    # Logarithmic (Fibonacci-like) spiral line on top
    phi = (1 + math.sqrt(5)) / 2
    b = math.log(phi) / (math.pi / 2)  # golden spiral constant
    points: list[tuple[float, float]] = []
    theta = 0.0
    # Choose start radius so the spiral spans a nice portion of the shell
    max_theta = math.radians(720)  # two full turns
    a = radius * 0.95 / math.exp(b * max_theta)
    steps = 90
    for i in range(steps + 1):
        t = max_theta * i / steps
        r = a * math.exp(b * t)
        x = cx + math.cos(t) * r
        y = cy + math.sin(t) * r
        points.append((x, y))
    if len(points) >= 2:
        pygame.draw.lines(surf, sh, False, points, 2)

    # Tiny center dot
    pygame.draw.circle(surf, sh, (int(cx), int(cy)), 2)

    _shell_cache[key] = surf
    return surf


# ---------- Board state ----------
@dataclass
class Piece:
    color: int  # index into SHELL_COLORS, or -1 for empty
    # pixel offset from its grid home (for fall/swap animation)
    dy: float = 0.0
    dx: float = 0.0
    # visual scale for explosion pop
    scale: float = 1.0
    fading: float = 0.0  # 0..1, 1 means fully exploded/invisible
    charged: bool = False  # part of a match-group waiting for manual detonation


def new_board(rng: random.Random) -> list[list[Piece]]:
    # Fill avoiding initial matches of 3+ same color in a row/col
    board: list[list[Piece]] = [[Piece(-1) for _ in range(GRID_COLS)] for _ in range(GRID_ROWS)]
    for r in range(GRID_ROWS):
        for c in range(GRID_COLS):
            while True:
                color = rng.randrange(NUM_COLORS)
                if c >= 2 and board[r][c - 1].color == color and board[r][c - 2].color == color:
                    continue
                if r >= 2 and board[r - 1][c].color == color and board[r - 2][c].color == color:
                    continue
                board[r][c] = Piece(color)
                break
    return board


def in_bounds(r: int, c: int) -> bool:
    return 0 <= r < GRID_ROWS and 0 <= c < GRID_COLS


def find_groups(board: list[list[Piece]]) -> list[list[tuple[int, int]]]:
    """Find connected groups (4-neighborhood) of same-color pieces with size >= 3."""
    seen = [[False] * GRID_COLS for _ in range(GRID_ROWS)]
    groups: list[list[tuple[int, int]]] = []
    for r in range(GRID_ROWS):
        for c in range(GRID_COLS):
            if seen[r][c] or board[r][c].color < 0:
                continue
            color = board[r][c].color
            stack = [(r, c)]
            group: list[tuple[int, int]] = []
            while stack:
                rr, cc = stack.pop()
                if not in_bounds(rr, cc) or seen[rr][cc]:
                    continue
                if board[rr][cc].color != color:
                    continue
                seen[rr][cc] = True
                group.append((rr, cc))
                stack.extend([(rr + 1, cc), (rr - 1, cc), (rr, cc + 1), (rr, cc - 1)])
            # Candy-Crush style: only explode if a straight line of >=3 exists
            # anywhere in the connected blob. Otherwise ignore (avoids exploding
            # diagonally-adjacent clusters that a player wouldn't consider a match).
            if has_line_of_three(group):
                groups.append(group)
    return groups


def has_line_of_three(cells: Iterable[tuple[int, int]]) -> bool:
    cell_set = set(cells)
    for r, c in cell_set:
        # horizontal
        if (r, c + 1) in cell_set and (r, c + 2) in cell_set:
            return True
        # vertical
        if (r + 1, c) in cell_set and (r + 2, c) in cell_set:
            return True
    return False


def recompute_charges(board: list[list[Piece]]) -> None:
    """Mark every piece belonging to a match-group (>=3, line-of-3) as charged."""
    groups = find_groups(board)
    charged_cells: set[tuple[int, int]] = set()
    for g in groups:
        for cell in g:
            charged_cells.add(cell)
    for r in range(GRID_ROWS):
        for c in range(GRID_COLS):
            board[r][c].charged = (r, c) in charged_cells


def charged_component(board: list[list[Piece]], r: int, c: int) -> list[tuple[int, int]]:
    """Flood-fill the charged same-color cluster containing (r, c).

    Returns an empty list if the cell is not charged.
    """
    if not in_bounds(r, c) or not board[r][c].charged:
        return []
    color = board[r][c].color
    stack = [(r, c)]
    seen: set[tuple[int, int]] = set()
    while stack:
        rr, cc = stack.pop()
        if (rr, cc) in seen or not in_bounds(rr, cc):
            continue
        if not board[rr][cc].charged or board[rr][cc].color != color:
            continue
        seen.add((rr, cc))
        stack.extend([(rr + 1, cc), (rr - 1, cc), (rr, cc + 1), (rr, cc - 1)])
    return list(seen)


# ---------- Game logic ----------
class Game:
    def __init__(self, seed: int | None = None) -> None:
        self.rng = random.Random(seed)
        self.board = new_board(self.rng)
        self.score = 0
        self.last_match_text = ""
        self.last_match_until = 0.0
        self.combo_level = 0
        self.selected: tuple[int, int] | None = None
        self.swap_anim: tuple[tuple[int, int], tuple[int, int], float, bool] | None = None
        # swap_anim = ((r1,c1),(r2,c2), progress 0..1, reverting?)
        self.exploding: list[tuple[int, int]] = []
        self.explode_t = 0.0
        self.falling = False
        self.fall_speed = 600.0  # pixels per second
        self.state = "idle"  # idle | swap | explode | fall | settle
        self.pending_swap_after: tuple[tuple[int, int], tuple[int, int]] | None = None

    # ---- Interaction ----
    def on_click(self, r: int, c: int, button: int = 1) -> None:
        """button: 1 = left (select/swap), 3 = right (detonate charged cluster)."""
        if self.state != "idle":
            return
        if not in_bounds(r, c):
            return

        if button == 3:
            if self.board[r][c].charged:
                self.detonate_at(r, c)
                self.selected = None
            return

        # Left click: selection / swap
        if self.selected is None:
            self.selected = (r, c)
            return
        if self.selected == (r, c):
            self.selected = None
            return
        sr, sc = self.selected
        if abs(sr - r) + abs(sc - c) == 1:
            self.begin_swap((sr, sc), (r, c))
            self.selected = None
        else:
            self.selected = (r, c)

    def begin_swap(self, a: tuple[int, int], b: tuple[int, int], reverting: bool = False) -> None:
        self.swap_anim = (a, b, 0.0, reverting)
        self.state = "swap"

    def apply_swap(self, a: tuple[int, int], b: tuple[int, int]) -> None:
        (r1, c1), (r2, c2) = a, b
        self.board[r1][c1], self.board[r2][c2] = self.board[r2][c2], self.board[r1][c1]

    # ---- Update / animation ----
    def update(self, dt: float) -> None:
        if self.state == "swap":
            assert self.swap_anim is not None
            a, b, t, reverting = self.swap_anim
            t = min(1.0, t + dt * 6.0)
            self.swap_anim = (a, b, t, reverting)
            if t >= 1.0:
                self.apply_swap(a, b)
                self.swap_anim = None
                if reverting:
                    self.state = "idle"
                else:
                    # Accept swap only if it produces/grows a match group
                    groups = find_groups(self.board)
                    involved = {a, b}
                    if any(involved.intersection(g) for g in groups):
                        self.combo_level = 0  # swap resets combo multiplier
                        recompute_charges(self.board)
                        self.state = "idle"
                    else:
                        self.begin_swap(a, b, reverting=True)
        elif self.state == "explode":
            self.explode_t += dt
            dur = 0.28
            p = min(1.0, self.explode_t / dur)
            for (r, c) in self.exploding:
                piece = self.board[r][c]
                piece.scale = 1.0 + 0.4 * math.sin(p * math.pi)
                piece.fading = p
            if self.explode_t >= dur:
                for (r, c) in self.exploding:
                    self.board[r][c] = Piece(-1)
                self.exploding = []
                self.start_fall()
        elif self.state == "fall":
            self.advance_fall(dt)
        elif self.state == "settle":
            # brief pause after fall, then re-charge any matches formed by cascade
            # (but do NOT auto-detonate — player decides)
            self.explode_t += dt
            if self.explode_t > 0.08:
                recompute_charges(self.board)
                self.state = "idle"

    def detonate_at(self, r: int, c: int) -> None:
        cells = charged_component(self.board, r, c)
        if not cells:
            return
        size = len(cells)
        tier = fib_tier(size)
        if tier == 0:
            return
        base = FIB_POINTS[tier]
        exact_mult = 2 if is_fib(size) else 1
        combo_mult = 1 + self.combo_level  # 1x, 2x, 3x ... within a planning phase
        gained = base * exact_mult * combo_mult
        self.score += gained
        self.combo_level += 1

        suffix = " EXATO!" if is_fib(size) else ""
        combo_text = f"  combo x{combo_mult}" if combo_mult > 1 else ""
        self.last_match_text = f"+{gained}  {FIB_LABELS[tier]} (x{size}){suffix}{combo_text}"
        self.last_match_until = 1.6

        self.exploding = cells
        self.explode_t = 0.0
        self.state = "explode"

    def start_fall(self) -> None:
        # For each column: pieces with color >= 0 fall down into empty slots,
        # then new pieces fill from above with negative dy so they "fall in".
        for c in range(GRID_COLS):
            # collect existing pieces from bottom to top
            stack = []
            for r in range(GRID_ROWS - 1, -1, -1):
                if self.board[r][c].color >= 0:
                    stack.append(self.board[r][c])
            # rebuild column
            write_r = GRID_ROWS - 1
            for p in stack:
                # new grid position is write_r; compute dy so it visually starts at its prior position
                self.board[write_r][c] = p
                write_r -= 1
            # fill remaining with new pieces coming from above
            new_idx = 0
            for r in range(write_r, -1, -1):
                new_piece = Piece(self.rng.randrange(NUM_COLORS))
                # start them above the board so they slide in
                new_piece.dy = -CELL * (new_idx + 1) - CELL
                self.board[r][c] = new_piece
                new_idx += 1
            # Now compute dy for existing shifted pieces: we lost the old positions,
            # so give all non-new pieces a small settle offset instead.
        # set dy for every piece so they all animate slightly (cheap & fine)
        for r in range(GRID_ROWS):
            for c in range(GRID_COLS):
                p = self.board[r][c]
                if p.dy == 0:
                    p.dy = -8  # tiny bounce
        self.state = "fall"

    def advance_fall(self, dt: float) -> None:
        still_moving = False
        step = self.fall_speed * dt
        for r in range(GRID_ROWS):
            for c in range(GRID_COLS):
                p = self.board[r][c]
                if p.color < 0:
                    continue
                if p.dy < 0:
                    p.dy = min(0, p.dy + step)
                    if p.dy < 0:
                        still_moving = True
                elif p.dy > 0:
                    p.dy = max(0, p.dy - step)
                    if p.dy > 0:
                        still_moving = True
                p.scale = 1.0
                p.fading = 0.0
        if not still_moving:
            self.state = "settle"
            self.explode_t = 0.0

    # ---- Rendering helpers ----
    def board_piece_pos(self, r: int, c: int) -> tuple[float, float]:
        p = self.board[r][c]
        dx, dy = p.dx, p.dy
        # during swap, animate the two pieces linearly between positions
        if self.swap_anim is not None:
            (r1, c1), (r2, c2), t, reverting = self.swap_anim
            eff_t = t
            if reverting:
                eff_t = t  # revert goes forward too; visually fine
            if (r, c) == (r1, c1):
                dx = (c2 - c1) * CELL * eff_t
                dy = (r2 - r1) * CELL * eff_t
            elif (r, c) == (r2, c2):
                dx = (c1 - c2) * CELL * eff_t
                dy = (r1 - r2) * CELL * eff_t
        return dx, dy


# ---------- Rendering ----------
def draw_background(screen: pygame.Surface) -> None:
    h = screen.get_height()
    for y in range(h):
        t = y / max(1, h - 1)
        col = (
            int(BG_TOP[0] * (1 - t) + BG_BOTTOM[0] * t),
            int(BG_TOP[1] * (1 - t) + BG_BOTTOM[1] * t),
            int(BG_TOP[2] * (1 - t) + BG_BOTTOM[2] * t),
        )
        pygame.draw.line(screen, col, (0, y), (screen.get_width(), y))


def draw_board(screen: pygame.Surface, game: Game, board_x: int, board_y: int) -> None:
    # Board backdrop
    backdrop = pygame.Rect(board_x - 6, board_y - 6, BOARD_W + 12, BOARD_H + 12)
    pygame.draw.rect(screen, (15, 20, 40), backdrop, border_radius=10)
    pygame.draw.rect(screen, PANEL_BORDER, backdrop, width=2, border_radius=10)

    # Grid lines (subtle)
    grid_surf = pygame.Surface((BOARD_W, BOARD_H), pygame.SRCALPHA)
    for i in range(1, GRID_COLS):
        pygame.draw.line(grid_surf, GRID_LINE, (i * CELL, 0), (i * CELL, BOARD_H))
    for i in range(1, GRID_ROWS):
        pygame.draw.line(grid_surf, GRID_LINE, (0, i * CELL), (BOARD_W, i * CELL))
    screen.blit(grid_surf, (board_x, board_y))

    # Charged glow (drawn under the shells so the shell sits on top)
    pulse_alpha = 110 + int(70 * math.sin(pygame.time.get_ticks() / 180))
    glow_surf = pygame.Surface((CELL, CELL), pygame.SRCALPHA)
    pygame.draw.circle(glow_surf, (255, 215, 80, pulse_alpha), (CELL // 2, CELL // 2), int(CELL * 0.44))
    pygame.draw.circle(glow_surf, (255, 235, 160, min(255, pulse_alpha + 40)), (CELL // 2, CELL // 2), int(CELL * 0.44), width=2)
    for r in range(GRID_ROWS):
        for c in range(GRID_COLS):
            p = game.board[r][c]
            if not p.charged or p.color < 0 or p.fading > 0:
                continue
            dx, dy = game.board_piece_pos(r, c)
            cx = board_x + c * CELL + CELL / 2 + dx
            cy = board_y + r * CELL + CELL / 2 + dy
            rect = glow_surf.get_rect(center=(cx, cy))
            screen.blit(glow_surf, rect)

    # Draw pieces
    for r in range(GRID_ROWS):
        for c in range(GRID_COLS):
            p = game.board[r][c]
            if p.color < 0:
                continue
            dx, dy = game.board_piece_pos(r, c)
            cx = board_x + c * CELL + CELL / 2 + dx
            cy = board_y + r * CELL + CELL / 2 + dy
            shell = render_shell(p.color)
            if p.scale != 1.0 or p.fading > 0:
                scale = p.scale * (1.0 - 0.4 * p.fading)
                alpha = int(255 * (1.0 - p.fading))
                w = max(1, int(CELL * scale))
                img = pygame.transform.smoothscale(shell, (w, w))
                img.set_alpha(alpha)
                rect = img.get_rect(center=(cx, cy))
                screen.blit(img, rect)
            else:
                rect = shell.get_rect(center=(cx, cy))
                screen.blit(shell, rect)

    # Selection highlight
    if game.selected is not None:
        sr, sc = game.selected
        pulse = int(6 + 4 * math.sin(pygame.time.get_ticks() / 120))
        rect = pygame.Rect(
            board_x + sc * CELL + 2,
            board_y + sr * CELL + 2,
            CELL - 4,
            CELL - 4,
        )
        pygame.draw.rect(screen, HIGHLIGHT, rect, width=3, border_radius=8)
        pygame.draw.rect(
            screen, HIGHLIGHT,
            rect.inflate(pulse, pulse),
            width=1, border_radius=10,
        )


def draw_sidebar(screen: pygame.Surface, game: Game, x: int, y: int, font: pygame.font.Font, small: pygame.font.Font, big: pygame.font.Font) -> None:
    panel = pygame.Rect(x, y, SIDEBAR_W, BOARD_H)
    pygame.draw.rect(screen, PANEL_BG, panel, border_radius=12)
    pygame.draw.rect(screen, PANEL_BORDER, panel, width=2, border_radius=12)

    pad = 16
    title = big.render("Fibonacci Shells", True, TEXT_COLOR)
    screen.blit(title, (x + pad, y + pad))

    score_label = small.render("PONTUACAO", True, TEXT_DIM)
    screen.blit(score_label, (x + pad, y + pad + 46))
    score_txt = big.render(f"{game.score}", True, HIGHLIGHT)
    screen.blit(score_txt, (x + pad, y + pad + 64))

    # Last match flash
    if game.last_match_until > 0 and game.last_match_text:
        alpha = min(255, int(255 * min(1.0, game.last_match_until / 0.4)))
        txt = font.render(game.last_match_text, True, HIGHLIGHT)
        txt.set_alpha(alpha)
        screen.blit(txt, (x + pad, y + pad + 110))

    # Current combo multiplier for the next detonation
    if game.combo_level > 0:
        combo_txt = small.render(
            f"próx. detonação: x{game.combo_level + 1}", True, HIGHLIGHT,
        )
        screen.blit(combo_txt, (x + pad, y + pad + 136))

    # Tier table
    header_y = y + pad + 160
    header = small.render("TIERS FIBONACCI", True, TEXT_DIM)
    screen.blit(header, (x + pad, header_y))
    row_y = header_y + 24
    for size in FIB_SIZES[:5]:
        label = FIB_LABELS[size]
        line = f"{label}  x{size:<3}  {FIB_POINTS[size]} pts"
        txt = small.render(line, True, TEXT_COLOR)
        screen.blit(txt, (x + pad, row_y))
        row_y += 20

    tip_y = row_y + 16
    tips = [
        "- Esq: selecionar/trocar",
        "- Dir: detonar grupo",
        "  carregado (dourado)",
        "- Cresca p/ Fibonacci",
        "  (3-5-8-13...) = 2x",
        "- Detonar em seq. sem",
        "  trocar = combo +1x",
        "",
        "[R] reiniciar [ESC] sair",
    ]
    for line in tips:
        screen.blit(small.render(line, True, TEXT_DIM), (x + pad, tip_y))
        tip_y += 18


# ---------- Main ----------
def main() -> None:
    pygame.init()
    pygame.display.set_caption("Fibonacci Shells")
    screen = pygame.display.set_mode((WINDOW_W, WINDOW_H))
    clock = pygame.time.Clock()

    font = pygame.font.SysFont("dejavusans", 18)
    small = pygame.font.SysFont("dejavusans", 14)
    big = pygame.font.SysFont("dejavusans", 26, bold=True)

    game = Game()

    board_x = BOARD_MARGIN
    board_y = BOARD_MARGIN
    sidebar_x = board_x + BOARD_W + BOARD_MARGIN
    sidebar_y = board_y

    running = True
    while running:
        dt = clock.tick(FPS) / 1000.0

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_r:
                    game = Game()
            elif event.type == pygame.MOUSEBUTTONDOWN and event.button in (1, 3):
                mx, my = event.pos
                if board_x <= mx < board_x + BOARD_W and board_y <= my < board_y + BOARD_H:
                    c = (mx - board_x) // CELL
                    r = (my - board_y) // CELL
                    game.on_click(int(r), int(c), event.button)

        game.update(dt)
        if game.last_match_until > 0:
            game.last_match_until = max(0.0, game.last_match_until - dt)

        draw_background(screen)
        draw_board(screen, game, board_x, board_y)
        draw_sidebar(screen, game, sidebar_x, sidebar_y, font, small, big)

        pygame.display.flip()

    pygame.quit()
    sys.exit(0)


if __name__ == "__main__":
    main()
