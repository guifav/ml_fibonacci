import 'dart:math';

const int gridCols = 8;
const int gridRows = 8;

/// Fibonacci tiers recognised by the game (F_4 onwards).
const List<int> fibSizes = [3, 5, 8, 13, 21, 34, 55];
const Map<int, int> fibPoints = {
  3: 30, 5: 80, 8: 210, 13: 550, 21: 1440, 34: 3780, 55: 9900,
};
const Map<int, String> fibLabels = {
  3: 'F₄', 5: 'F₅', 8: 'F₆', 13: 'F₇', 21: 'F₈', 34: 'F₉', 55: 'F₁₀',
};

int fibTier(int size) {
  var tier = 0;
  for (final f in fibSizes) {
    if (f <= size) {
      tier = f;
    } else {
      break;
    }
  }
  return tier;
}

bool isFib(int size) => fibSizes.contains(size);

typedef Cell = (int row, int col);

class Piece {
  int color;  // 0..numColors-1, -1 = empty slot

  // Pixel offset from its grid home (used for fall / swap animation).
  double dx = 0;
  double dy = 0;
  // Scale & fade during detonation (scale: 1.0 normal; fading: 0..1 explode progress).
  double scale = 1.0;
  double fading = 0.0;
  // Whether this piece is part of a "charged" cluster that can be detonated.
  bool charged = false;
  // Continuous 0..1 phase for the pulse animation on charged pieces.
  double pulsePhase = 0.0;

  Piece(this.color);

  bool get isEmpty => color < 0;
}

bool inBounds(int r, int c) =>
    r >= 0 && r < gridRows && c >= 0 && c < gridCols;

/// Create an initial board with no pre-existing horizontal/vertical run of 3.
List<List<Piece>> newBoard(Random rng) {
  final board = List.generate(
    gridRows,
    (_) => List.generate(gridCols, (_) => Piece(-1)),
  );
  for (var r = 0; r < gridRows; r++) {
    for (var c = 0; c < gridCols; c++) {
      while (true) {
        final color = rng.nextInt(numColors);
        if (c >= 2 &&
            board[r][c - 1].color == color &&
            board[r][c - 2].color == color) {
          continue;
        }
        if (r >= 2 &&
            board[r - 1][c].color == color &&
            board[r - 2][c].color == color) {
          continue;
        }
        board[r][c] = Piece(color);
        break;
      }
    }
  }
  return board;
}

/// Groups of connected same-colour cells (4-neighbourhood) containing at
/// least one straight line of 3. Returns a list of cell lists.
List<List<Cell>> findGroups(List<List<Piece>> board) {
  final seen = List.generate(gridRows, (_) => List.filled(gridCols, false));
  final groups = <List<Cell>>[];
  for (var r = 0; r < gridRows; r++) {
    for (var c = 0; c < gridCols; c++) {
      if (seen[r][c] || board[r][c].isEmpty) continue;
      final color = board[r][c].color;
      final group = <Cell>[];
      final stack = <Cell>[(r, c)];
      while (stack.isNotEmpty) {
        final (rr, cc) = stack.removeLast();
        if (!inBounds(rr, cc) || seen[rr][cc]) continue;
        if (board[rr][cc].color != color) continue;
        seen[rr][cc] = true;
        group.add((rr, cc));
        stack.addAll([(rr + 1, cc), (rr - 1, cc), (rr, cc + 1), (rr, cc - 1)]);
      }
      if (_hasLineOfThree(group)) groups.add(group);
    }
  }
  return groups;
}

bool _hasLineOfThree(List<Cell> cells) {
  final set = cells.toSet();
  for (final (r, c) in cells) {
    if (set.contains((r, c + 1)) && set.contains((r, c + 2))) return true;
    if (set.contains((r + 1, c)) && set.contains((r + 2, c))) return true;
  }
  return false;
}

/// Flag every cell that is part of a chargeable group as `charged`.
void recomputeCharges(List<List<Piece>> board) {
  for (var r = 0; r < gridRows; r++) {
    for (var c = 0; c < gridCols; c++) {
      board[r][c].charged = false;
    }
  }
  for (final group in findGroups(board)) {
    for (final (r, c) in group) {
      board[r][c].charged = true;
    }
  }
}

/// Find all cells that belong to the connected group of `(r, c)` (same colour,
/// 4-neighbourhood). Returns empty list if the cell is empty.
List<Cell> groupContaining(List<List<Piece>> board, int r, int c) {
  if (!inBounds(r, c) || board[r][c].isEmpty) return const [];
  final color = board[r][c].color;
  final seen = <Cell>{};
  final stack = <Cell>[(r, c)];
  while (stack.isNotEmpty) {
    final cell = stack.removeLast();
    final (rr, cc) = cell;
    if (!inBounds(rr, cc) || seen.contains(cell)) continue;
    if (board[rr][cc].color != color) continue;
    seen.add(cell);
    stack.addAll([(rr + 1, cc), (rr - 1, cc), (rr, cc + 1), (rr, cc - 1)]);
  }
  return seen.toList();
}
