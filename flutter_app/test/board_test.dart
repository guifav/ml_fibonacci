import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fibonacci_shells/engine/board.dart';

void main() {
  test('fibTier', () {
    expect(fibTier(2), 0);
    expect(fibTier(3), 3);
    expect(fibTier(4), 3);
    expect(fibTier(5), 5);
    expect(fibTier(7), 5);
    expect(fibTier(8), 8);
    expect(fibTier(12), 8);
    expect(fibTier(13), 13);
  });

  test('isFib', () {
    expect(isFib(3), true);
    expect(isFib(4), false);
    expect(isFib(5), true);
    expect(isFib(8), true);
    expect(isFib(9), false);
  });

  test('newBoard has no initial lines of 3', () {
    final rng = Random(42);
    final board = newBoard(rng);
    for (var r = 0; r < gridRows; r++) {
      for (var c = 0; c < gridCols; c++) {
        if (c >= 2) {
          expect(
            !(board[r][c].color == board[r][c - 1].color &&
                board[r][c].color == board[r][c - 2].color),
            true,
            reason: 'horizontal triple at $r,$c',
          );
        }
        if (r >= 2) {
          expect(
            !(board[r][c].color == board[r - 1][c].color &&
                board[r][c].color == board[r - 2][c].color),
            true,
            reason: 'vertical triple at $r,$c',
          );
        }
      }
    }
  });

  List<List<Piece>> checkerboard({int bgA = 2, int bgB = 3}) {
    return List.generate(
      gridRows,
      (r) => List.generate(
        gridCols,
        (c) => Piece((r + c).isEven ? bgA : bgB),
      ),
    );
  }

  test('findGroups detects isolated 3 and 5 runs', () {
    final board = checkerboard();
    // Plant a horizontal 3-run of color 0 at row 0
    for (var c = 0; c < 3; c++) {
      board[0][c] = Piece(0);
    }
    // Plant a 5-run at row 2 (separated from row 0 by the checkerboard row 1)
    for (var c = 0; c < 5; c++) {
      board[2][c] = Piece(1);
    }
    final groups = findGroups(board);
    final sizes = groups.map((g) => g.length).toList()..sort();
    expect(sizes, [3, 5]);
  });

  test('recomputeCharges flags only cells in valid groups', () {
    final board = checkerboard();
    for (var c = 0; c < 3; c++) {
      board[0][c] = Piece(0);
    }
    recomputeCharges(board);
    // The 3-run is charged
    expect(board[0][0].charged, true);
    expect(board[0][1].charged, true);
    expect(board[0][2].charged, true);
    // Background is not
    expect(board[1][0].charged, false);
  });

  test('groupContaining finds only same-colour connected neighbours', () {
    final board = checkerboard();
    for (var c = 0; c < 5; c++) {
      board[3][c] = Piece(4);
    }
    final group = groupContaining(board, 3, 2);
    expect(group.length, 5);
    // Cells outside are excluded
    expect(group.contains((2, 2)), false);
  });

  test('charges ignore diagonal-only connections', () {
    final board = checkerboard();
    // Three color-0 cells in a diagonal — no straight line of 3
    board[0][0] = Piece(0);
    board[1][1] = Piece(0);
    board[2][2] = Piece(0);
    recomputeCharges(board);
    expect(board[0][0].charged, false);
    expect(board[1][1].charged, false);
    expect(board[2][2].charged, false);
  });
}
