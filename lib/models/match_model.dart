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
        matchId: (json['matchId'] ?? json['match_id'] ?? '') as String,
        homeScore: json['homeScore'] as int? ?? json['home_score'] as int?,
        awayScore: json['awayScore'] as int? ?? json['away_score'] as int?,
        points: json['points'] as int?,
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
      final raw = json['matchDate'] as String? ??
          json['date'] as String? ??
          json['match_date'] as String? ??
          '';
      date = DateTime.parse(raw);
    } catch (_) {
      date = DateTime(2026, 6, 14);
    }

    final apiLocked = json['isLocked'] == true ||
        json['locked'] == true ||
        json['status'] == 'locked';
    // Also consider a match locked once it has started
    final timeLocked = date.isBefore(DateTime.now());

    return Match(
      id: (json['id'] ?? json['matchId'] ?? json['match_id'] ?? '') as String,
      homeTeam: (json['homeTeam'] ?? json['home_team'] ?? 'Time A') as String,
      awayTeam: (json['awayTeam'] ?? json['away_team'] ?? 'Time B') as String,
      homeFlag: (json['homeFlag'] ?? json['home_flag'] ?? '🏳') as String,
      awayFlag: (json['awayFlag'] ?? json['away_flag'] ?? '🏳') as String,
      matchDate: date,
      phase: (json['phase'] ??
              json['round'] ??
              json['stage'] ??
              'Fase de Grupos') as String,
      isLocked: apiLocked || timeLocked,
      officialHomeScore: json['homeScore'] as int? ??
          json['home_score'] as int? ??
          json['officialHomeScore'] as int?,
      officialAwayScore: json['awayScore'] as int? ??
          json['away_score'] as int? ??
          json['officialAwayScore'] as int?,
    );
  }
}


