class Guess {
  final String matchId;
  final int? homeScore;
  final int? awayScore;
  final int? points;

  const Guess({
    required this.matchId,
    this.homeScore,
    this.awayScore,
    this.points,
  });

  factory Guess.fromJson(Map<String, dynamic> json) => Guess(
        matchId: _asString(json['matchId'] ?? json['match_id']),
        homeScore: _asInt(json['homeScore'] ?? json['home_score']),
        awayScore: _asInt(json['awayScore'] ?? json['away_score']),
        points: _asInt(json['points']),
      );

  Map<String, dynamic> toJson() => {
        'matchId': matchId,
        'homeScore': homeScore,
        'awayScore': awayScore,
      };
}

class Match {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String homeFlag;
  final String awayFlag;
  final DateTime matchDate;
  final String phase;
  final bool isLocked;
  final int? officialHomeScore;
  final int? officialAwayScore;
  Guess? myGuess;

  Match({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeFlag,
    required this.awayFlag,
    required this.matchDate,
    required this.phase,
    required this.isLocked,
    this.officialHomeScore,
    this.officialAwayScore,
    this.myGuess,
  });

  bool get hasOfficialResult =>
      officialHomeScore != null && officialAwayScore != null;

  factory Match.fromJson(Map<String, dynamic> json) {
    DateTime date;
    try {
      final raw = _asString(
        json['matchDate'] ?? json['date'] ?? json['match_date'],
      );
      date = DateTime.parse(raw);
    } catch (_) {
      date = DateTime(2026, 6, 14);
    }

    final apiLocked = json['isLocked'] == true ||
        json['locked'] == true ||
        _asString(json['status']).toLowerCase() == 'locked';
    // Also consider a match locked once it has started
    final timeLocked = date.isBefore(DateTime.now());

    return Match(
      id: _asString(json['id'] ?? json['matchId'] ?? json['match_id']),
      homeTeam: _asString(
        json['homeTeam'] ?? json['home_team'] ?? json['homeName'],
        fallback: 'Time A',
      ),
      awayTeam: _asString(
        json['awayTeam'] ?? json['away_team'] ?? json['awayName'],
        fallback: 'Time B',
      ),
      homeFlag: _asString(json['homeFlag'] ?? json['home_flag'], fallback: '🏳'),
      awayFlag: _asString(json['awayFlag'] ?? json['away_flag'], fallback: '🏳'),
      matchDate: date,
      phase: _asString(
        json['phase'] ?? json['round'] ?? json['stage'],
        fallback: 'Fase de Grupos',
      ),
      isLocked: apiLocked || timeLocked,
      officialHomeScore: _asInt(
        json['homeScore'] ?? json['home_score'] ?? json['officialHomeScore'],
      ),
      officialAwayScore: _asInt(
        json['awayScore'] ?? json['away_score'] ?? json['officialAwayScore'],
      ),
    );
  }
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
  return value.toString();
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}


