import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'engine/board.dart';
import 'engine/fibonacci_game.dart';
import 'engine/palette.dart';
import 'engine/scores.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final FibonacciGame _game;
  late final Ticker _hudTicker;
  final ScoreStore _store = ScoreStore();
  List<ScoreEntry> _leaderboard = const [];
  int _lastRank = -1;
  bool _showGameOver = false;

  @override
  void initState() {
    super.initState();
    _game = FibonacciGame();
    _game.onGameOver = _handleGameOver;
    _store.init().then((_) {
      if (!mounted) return;
      setState(() {
        _leaderboard = _store.load();
      });
    });
    _hudTicker = createTicker((_) {
      // Rebuild HUD every frame so timer / score animate smoothly.
      if (mounted) setState(() {});
    })
      ..start();
  }

  @override
  void dispose() {
    _hudTicker.dispose();
    super.dispose();
  }

  void _handleGameOver(int score, int bestTier) {
    _store.record(score, bestTier).then((result) {
      if (!mounted) return;
      final (scores, rank) = result;
      setState(() {
        _leaderboard = scores;
        _lastRank = rank;
        _showGameOver = true;
      });
    });
  }

  void _restart() {
    setState(() {
      _showGameOver = false;
      _lastRank = -1;
      _game.reset();
    });
  }

  String _formatTime(double seconds) {
    final s = seconds.ceil().clamp(0, 9999);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _game.timeLeft < 15;
    return Scaffold(
      backgroundColor: bgBottom,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Game canvas
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => _game.handleTap(details.localPosition),
                    onLongPressStart: (details) =>
                        _game.handleLongPress(details.localPosition),
                    child: GameWidget(game: _game),
                  ),
                ),

                // Top HUD
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: _TopHud(
                    score: _game.score,
                    time: _formatTime(_game.timeLeft),
                    urgent: urgent,
                    flashText: _game.lastMatchUntil > 0
                        ? _game.lastMatchText
                        : '',
                    flashOpacity:
                        (_game.lastMatchUntil / 1.6).clamp(0.0, 1.0),
                  ),
                ),

                // Bottom HUD (combo + next-combo indicator + leaderboard)
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: _BottomHud(
                    comboLevel: _game.comboLevel,
                    leaderboard: _leaderboard.take(3).toList(),
                    hint: _game.state == GameState.idle
                        ? 'Toque para selecionar · segure no cluster dourado para detonar'
                        : '',
                  ),
                ),

                // Game over modal
                if (_showGameOver)
                  Positioned.fill(
                    child: _GameOverOverlay(
                      score: _game.score,
                      bestTier: _game.bestTierThisGame,
                      rank: _lastRank,
                      leaderboard: _leaderboard,
                      onRestart: _restart,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopHud extends StatelessWidget {
  final int score;
  final String time;
  final bool urgent;
  final String flashText;
  final double flashOpacity;
  const _TopHud({
    required this.score,
    required this.time,
    required this.urgent,
    required this.flashText,
    required this.flashOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _chip(
              'TEMPO',
              time,
              valueColor: urgent ? urgentColor : highlightColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _chip('PONTUACAO', '$score',
                  valueColor: highlightColor, alignEnd: true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: flashText.isEmpty ? 0 : flashOpacity,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              flashText,
              style: const TextStyle(
                color: highlightColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, String value,
      {Color valueColor = textColor, bool alignEnd = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: panelBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: textDim,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomHud extends StatelessWidget {
  final int comboLevel;
  final List<ScoreEntry> leaderboard;
  final String hint;
  const _BottomHud({
    required this.comboLevel,
    required this.leaderboard,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (comboLevel > 0)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'próx. detonação: x${comboLevel + 1}',
              style: const TextStyle(
                color: highlightColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: panelBorder, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MELHORES',
                style: TextStyle(
                  color: textDim,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              if (leaderboard.isEmpty)
                const Text(
                  '— nenhum ainda —',
                  style: TextStyle(color: textDim, fontSize: 13),
                )
              else
                for (var i = 0; i < leaderboard.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      '${i + 1}. ${leaderboard[i].score.toString().padLeft(5)}  '
                      '${fibLabels[leaderboard[i].bestTier] ?? "-"}',
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              if (hint.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  hint,
                  style: const TextStyle(color: textDim, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  final int score;
  final int bestTier;
  final int rank;
  final List<ScoreEntry> leaderboard;
  final VoidCallback onRestart;

  const _GameOverOverlay({
    required this.score,
    required this.bestTier,
    required this.rank,
    required this.leaderboard,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: panelBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: panelBorder, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'FIM DE JOGO',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '$score',
                  style: const TextStyle(
                    color: highlightColor,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  bestTier > 0
                      ? 'maior grupo: ${fibLabels[bestTier]}'
                      : 'sem detonações',
                  style: const TextStyle(color: textDim, fontSize: 14),
                ),
                const SizedBox(height: 8),
                if (rank == 0 && score > 0)
                  const Text(
                    'NOVO RECORDE!',
                    style: TextStyle(
                      color: highlightColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else if (rank >= 0)
                  Text(
                    'você ficou em #${rank + 1}',
                    style: const TextStyle(
                      color: highlightColor,
                      fontSize: 16,
                    ),
                  ),
                const SizedBox(height: 18),
                const Text(
                  'TOP 10',
                  style: TextStyle(
                    color: textDim,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                if (leaderboard.isEmpty)
                  const Text('— vazio —',
                      style: TextStyle(color: textDim, fontSize: 14))
                else
                  for (var i = 0; i < leaderboard.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${i + 1}.',
                              style: TextStyle(
                                color: i == rank ? highlightColor : textDim,
                                fontSize: 14,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              leaderboard[i].score.toString(),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: i == rank ? highlightColor : textColor,
                                fontSize: 15,
                                fontWeight: i == rank
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 36,
                            child: Text(
                              fibLabels[leaderboard[i].bestTier] ?? '-',
                              style: TextStyle(
                                color: i == rank ? highlightColor : textColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _fmtDate(leaderboard[i].date),
                            style: const TextStyle(
                              color: textDim,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: highlightColor,
                    foregroundColor: bgBottom,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: onRestart,
                  child: const Text(
                    'NOVA PARTIDA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
