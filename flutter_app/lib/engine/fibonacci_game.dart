import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'board.dart';
import 'palette.dart';
import 'particles.dart';
import 'shell_painter.dart';

const double gameDuration = 90.0;

enum GameState { idle, swap, explode, fall, settle, gameover }

typedef GameOverCallback = void Function(int score, int bestTier);

class FibonacciGame extends FlameGame {
  final Random rng;
  late List<List<Piece>> board;
  GameState state = GameState.idle;

  // Score / timing
  int score = 0;
  int bestTierThisGame = 0;
  int comboLevel = 0;
  double timeLeft = gameDuration;

  // Last detonation info (for HUD flash)
  String lastMatchText = '';
  double lastMatchUntil = 0;

  // Input state
  Cell? selected;

  // Swap animation state
  Cell? swapA;
  Cell? swapB;
  double swapT = 0;
  bool swapReverting = false;

  // Explosion + fall
  List<Cell> exploding = const [];
  double explodeT = 0;
  final double fallSpeed = 600.0;
  double settleT = 0;

  // Visual systems
  final ParticleSystem particles = ParticleSystem();
  final List<ScorePopup> scorePopups = [];
  double shakeAmount = 0;
  double shakeTime = 0;
  late final Random _shakeRng = Random();

  // Layout (set on first render based on canvasSize)
  double boardOriginX = 0;
  double boardOriginY = 0;
  double cellSize = 64;

  // Callbacks to the Flutter UI layer
  GameOverCallback? onGameOver;
  void Function()? onStateChanged;

  FibonacciGame({Random? seed}) : rng = seed ?? Random() {
    reset();
  }

  void reset() {
    board = newBoard(rng);
    score = 0;
    bestTierThisGame = 0;
    comboLevel = 0;
    timeLeft = gameDuration;
    selected = null;
    swapA = swapB = null;
    swapT = 0;
    state = GameState.idle;
    exploding = const [];
    particles.particles.clear();
    particles.sparkles.clear();
    particles.shockRings.clear();
    scorePopups.clear();
    shakeAmount = 0;
    shakeTime = 0;
    lastMatchText = '';
    lastMatchUntil = 0;
    onStateChanged?.call();
  }

  // ---------- Layout ----------
  void _layout(Vector2 size) {
    final availableWidth = size.x - 16;
    final availableHeight = size.y - 16;
    cellSize = min(availableWidth / gridCols, availableHeight / gridRows);
    final boardW = cellSize * gridCols;
    final boardH = cellSize * gridRows;
    boardOriginX = (size.x - boardW) / 2;
    boardOriginY = (size.y - boardH) / 2;
  }

  // ---------- Input ----------
  /// Called by the Flutter GestureDetector; coordinates are in local game
  /// coordinates (already adjusted to the GameWidget's size).
  void handleTap(Offset localPos) {
    if (state == GameState.gameover || state != GameState.idle) return;
    final cell = _cellAt(localPos);
    if (cell == null) return;
    final (r, c) = cell;
    if (selected == null) {
      selected = cell;
      return;
    }
    if (selected == cell) {
      selected = null;
      return;
    }
    final (sr, sc) = selected!;
    if ((sr - r).abs() + (sc - c).abs() == 1) {
      _beginSwap(selected!, cell);
      selected = null;
    } else {
      selected = cell;
    }
  }

  void handleLongPress(Offset localPos) {
    if (state == GameState.gameover || state != GameState.idle) return;
    final cell = _cellAt(localPos);
    if (cell == null) return;
    final (r, c) = cell;
    if (!board[r][c].charged) return;
    _detonateAt(r, c);
  }

  Cell? _cellAt(Offset localPos) {
    final x = localPos.dx - boardOriginX;
    final y = localPos.dy - boardOriginY;
    if (x < 0 || y < 0) return null;
    final c = (x ~/ cellSize);
    final r = (y ~/ cellSize);
    if (!inBounds(r, c)) return null;
    return (r, c);
  }

  // ---------- Gameplay ----------
  void _beginSwap(Cell a, Cell b, {bool reverting = false}) {
    swapA = a;
    swapB = b;
    swapT = 0;
    swapReverting = reverting;
    state = GameState.swap;
  }

  void _applySwap(Cell a, Cell b) {
    final (r1, c1) = a;
    final (r2, c2) = b;
    final tmp = board[r1][c1];
    board[r1][c1] = board[r2][c2];
    board[r2][c2] = tmp;
  }

  void _detonateAt(int r, int c) {
    final group = groupContaining(board, r, c);
    if (group.isEmpty) return;
    final size = group.length;
    final tier = fibTier(size);
    if (tier == 0) return;

    final base = fibPoints[tier]!;
    final exactMult = isFib(size) ? 2 : 1;
    final comboMult = 1 + comboLevel;
    final gained = base * exactMult * comboMult;
    score += gained;
    comboLevel += 1;
    if (tier > bestTierThisGame) bestTierThisGame = tier;

    final suffix = isFib(size) ? ' EXATO!' : '';
    final comboSfx = comboMult > 1 ? '  combo x$comboMult' : '';
    lastMatchText = '+$gained  ${fibLabels[tier]} (x$size)$suffix$comboSfx';
    lastMatchUntil = 1.6;

    // Spawn particles at each detonated cell
    final colorIdx = board[group.first.$1][group.first.$2].color;
    for (final cell in group) {
      final (rr, cc) = cell;
      final pos = _cellCenter(rr, cc);
      particles.spawnExplosion(pos, colorIdx: colorIdx, tierSize: tier);
    }

    // Floating score popup at group centroid
    var sumR = 0, sumC = 0;
    for (final (rr, cc) in group) {
      sumR += rr;
      sumC += cc;
    }
    final centroid = _cellCenter(sumR / group.length, sumC / group.length);
    scorePopups.add(
      ScorePopup(
        position: centroid,
        text: '+$gained  ${fibLabels[tier]}',
        isLarge: tier >= 8,
      ),
    );

    // Screen shake scaled to tier
    final shakeStrength = 4.0 + tier * 0.8;
    shakeAmount = max(shakeAmount, shakeStrength);
    shakeTime = max(shakeTime, 0.25 + tier * 0.03);

    exploding = group;
    explodeT = 0;
    state = GameState.explode;
    onStateChanged?.call();
  }

  Offset _cellCenter(num r, num c) {
    return Offset(
      boardOriginX + c.toDouble() * cellSize + cellSize / 2,
      boardOriginY + r.toDouble() * cellSize + cellSize / 2,
    );
  }

  void _startFall() {
    for (var c = 0; c < gridCols; c++) {
      final survivors = <Piece>[];
      for (var r = gridRows - 1; r >= 0; r--) {
        if (!board[r][c].isEmpty) survivors.add(board[r][c]);
      }
      var writeR = gridRows - 1;
      for (final p in survivors) {
        board[writeR][c] = p;
        writeR -= 1;
      }
      var newIdx = 0;
      for (var r = writeR; r >= 0; r--) {
        final np = Piece(rng.nextInt(numColors));
        np.dy = -cellSize * (newIdx + 1) - cellSize;
        board[r][c] = np;
        newIdx += 1;
      }
    }
    // Give existing pieces a tiny settle offset so motion isn't jarring.
    for (var r = 0; r < gridRows; r++) {
      for (var c = 0; c < gridCols; c++) {
        final p = board[r][c];
        if (p.dy == 0 && !p.isEmpty) p.dy = -8.0;
      }
    }
    state = GameState.fall;
  }

  void _advanceFall(double dt) {
    var stillMoving = false;
    final step = fallSpeed * dt;
    for (var r = 0; r < gridRows; r++) {
      for (var c = 0; c < gridCols; c++) {
        final p = board[r][c];
        if (p.isEmpty) continue;
        if (p.dy < 0) {
          p.dy = min(0.0, p.dy + step);
          if (p.dy < 0) stillMoving = true;
        } else if (p.dy > 0) {
          p.dy = max(0.0, p.dy - step);
          if (p.dy > 0) stillMoving = true;
        }
        p.scale = 1.0;
        p.fading = 0.0;
      }
    }
    if (!stillMoving) {
      state = GameState.settle;
      settleT = 0;
    }
  }

  void _enterGameOver() {
    if (state == GameState.gameover) return;
    state = GameState.gameover;
    selected = null;
    onGameOver?.call(score, bestTierThisGame);
    onStateChanged?.call();
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    _layout(newSize);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Pulse animation phase for charged pieces
    for (final row in board) {
      for (final p in row) {
        p.pulsePhase = (p.pulsePhase + dt * 3.5) % (2 * pi);
      }
    }

    // Particles & popups run always, even during gameover freeze
    particles.update(dt);
    for (final p in scorePopups) {
      p.update(dt);
    }
    scorePopups.removeWhere((p) => p.isDead);

    if (shakeTime > 0) {
      shakeTime -= dt;
      if (shakeTime <= 0) {
        shakeAmount = 0;
      }
    }

    if (lastMatchUntil > 0) lastMatchUntil = max(0.0, lastMatchUntil - dt);

    if (state != GameState.gameover) {
      timeLeft = max(0.0, timeLeft - dt);
      if (timeLeft <= 0) {
        _enterGameOver();
        return;
      }
    }

    switch (state) {
      case GameState.swap:
        swapT = min(1.0, swapT + dt * 6.0);
        if (swapT >= 1.0) {
          final a = swapA!, b = swapB!;
          _applySwap(a, b);
          swapA = swapB = null;
          if (swapReverting) {
            state = GameState.idle;
          } else {
            // Accept swap only if it creates a matchable group containing the
            // swapped cells; otherwise revert.
            final groups = findGroups(board);
            final involved = {a, b};
            final ok = groups.any(
              (g) => g.any(involved.contains),
            );
            if (ok) {
              comboLevel = 0;
              recomputeCharges(board);
              state = GameState.idle;
            } else {
              _beginSwap(a, b, reverting: true);
            }
          }
        }
        break;
      case GameState.explode:
        explodeT += dt;
        const dur = 0.28;
        final p = min(1.0, explodeT / dur);
        for (final cell in exploding) {
          final piece = board[cell.$1][cell.$2];
          piece.scale = 1.0 + 0.4 * sin(p * pi);
          piece.fading = p;
        }
        if (explodeT >= dur) {
          for (final cell in exploding) {
            board[cell.$1][cell.$2] = Piece(-1);
          }
          exploding = const [];
          _startFall();
        }
        break;
      case GameState.fall:
        _advanceFall(dt);
        break;
      case GameState.settle:
        settleT += dt;
        if (settleT > 0.08) {
          recomputeCharges(board);
          state = GameState.idle;
        }
        break;
      case GameState.idle:
      case GameState.gameover:
        break;
    }
  }

  @override
  void render(Canvas canvas) {
    if (size.x <= 0 || cellSize <= 0) return;
    // Gradient backdrop
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.y),
        [bgTop, bgBottom],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);

    // Apply screen shake
    canvas.save();
    if (shakeAmount > 0) {
      final t = (shakeTime).clamp(0.0, 1.0);
      final dx = (_shakeRng.nextDouble() - 0.5) * 2 * shakeAmount * t;
      final dy = (_shakeRng.nextDouble() - 0.5) * 2 * shakeAmount * t;
      canvas.translate(dx, dy);
    }

    // Subtle board backdrop
    final boardRect = Rect.fromLTWH(
      boardOriginX,
      boardOriginY,
      cellSize * gridCols,
      cellSize * gridRows,
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(boardRect.inflate(6), ui.Radius.circular(14)),
      Paint()..color = Color(0xFF0A1028),
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(boardRect.inflate(6), ui.Radius.circular(14)),
      Paint()
        ..color = panelBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Grid lines
    final gridPaint = Paint()
      ..color = Color.fromARGB(24, 255, 255, 255)
      ..strokeWidth = 1;
    for (var i = 1; i < gridCols; i++) {
      canvas.drawLine(
        Offset(boardOriginX + i * cellSize, boardOriginY),
        Offset(boardOriginX + i * cellSize, boardOriginY + cellSize * gridRows),
        gridPaint,
      );
    }
    for (var i = 1; i < gridRows; i++) {
      canvas.drawLine(
        Offset(boardOriginX, boardOriginY + i * cellSize),
        Offset(boardOriginX + cellSize * gridCols, boardOriginY + i * cellSize),
        gridPaint,
      );
    }

    // Pieces
    for (var r = 0; r < gridRows; r++) {
      for (var c = 0; c < gridCols; c++) {
        final p = board[r][c];
        if (p.isEmpty) continue;
        final pos = _pieceRenderPos(r, c, p);
        final pulse = p.charged ? (0.55 + 0.45 * sin(p.pulsePhase)) : 0.0;
        paintShell(
          canvas,
          center: pos,
          radius: cellSize * 0.42,
          colorIdx: p.color,
          pulse: pulse,
          scale: p.scale,
          opacity: 1 - p.fading,
        );
      }
    }

    // Selection highlight
    if (selected != null) {
      final (sr, sc) = selected!;
      final rect = Rect.fromLTWH(
        boardOriginX + sc * cellSize + 2,
        boardOriginY + sr * cellSize + 2,
        cellSize - 4,
        cellSize - 4,
      );
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(10)),
        Paint()
          ..color = highlightColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // Particles + score popups
    particles.render(canvas);
    for (final pop in scorePopups) {
      pop.render(canvas);
    }

    canvas.restore();
  }

  Offset _pieceRenderPos(int r, int c, Piece p) {
    var dx = p.dx;
    var dy = p.dy;
    if (swapA != null && swapB != null) {
      final (r1, c1) = swapA!;
      final (r2, c2) = swapB!;
      if (r == r1 && c == c1) {
        dx = (c2 - c1) * cellSize * swapT;
        dy = (r2 - r1) * cellSize * swapT;
      } else if (r == r2 && c == c2) {
        dx = (c1 - c2) * cellSize * swapT;
        dy = (r1 - r2) * cellSize * swapT;
      }
    }
    return Offset(
      boardOriginX + c * cellSize + cellSize / 2 + dx,
      boardOriginY + r * cellSize + cellSize / 2 + dy,
    );
  }
}
