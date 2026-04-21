import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String _scoresKey = 'fibonacci_shells.scores';
const int maxScores = 10;

class ScoreEntry {
  final int score;
  final int bestTier;
  final DateTime date;

  ScoreEntry({
    required this.score,
    required this.bestTier,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'score': score,
        'bestTier': bestTier,
        'date': date.toIso8601String(),
      };

  factory ScoreEntry.fromJson(Map<String, dynamic> j) => ScoreEntry(
        score: j['score'] as int? ?? 0,
        bestTier: j['bestTier'] as int? ?? 0,
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
      );
}

class ScoreStore {
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<ScoreEntry> load() {
    final raw = _prefs?.getString(_scoresKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ScoreEntry.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<ScoreEntry> scores) async {
    final encoded = jsonEncode(scores.map((s) => s.toJson()).toList());
    await _prefs?.setString(_scoresKey, encoded);
  }

  /// Add a new score and persist. Returns the updated leaderboard and the
  /// rank (0-based) of the new entry, or -1 if it didn't make the cut.
  Future<(List<ScoreEntry>, int)> record(int score, int bestTier) async {
    final scores = load();
    final entry =
        ScoreEntry(score: score, bestTier: bestTier, date: DateTime.now());
    scores.add(entry);
    scores.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.bestTier.compareTo(a.bestTier);
    });
    if (scores.length > maxScores) {
      scores.removeRange(maxScores, scores.length);
    }
    await _save(scores);
    final rank = scores.indexOf(entry);
    return (scores, rank);
  }
}
