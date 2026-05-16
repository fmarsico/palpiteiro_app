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

  /// Calculate points if the guess matches the official result exactly
  /// Returns 10 points for exact match, 0 otherwise or if no official result
  int calculatePoints({
    required int? officialHomeScore,
    required int? officialAwayScore,
  }) {
    if (officialHomeScore == null || officialAwayScore == null) return 0;
    if (homeScore == null || awayScore == null) return 0;
    
    // Exact match: award 10 points
    if (homeScore == officialHomeScore && awayScore == officialAwayScore) {
      return 10;
    }
    return 0;
  }

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
  final String? groupCode;
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
    this.groupCode,
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

    final homeTeamMap = json['homeTeam'] is Map<String, dynamic>
        ? json['homeTeam'] as Map<String, dynamic>
        : null;
    final awayTeamMap = json['awayTeam'] is Map<String, dynamic>
        ? json['awayTeam'] as Map<String, dynamic>
        : null;
    final resultMap = json['result'] is Map<String, dynamic>
        ? json['result'] as Map<String, dynamic>
        : null;

    return Match(
      id: _asString(json['id'] ?? json['matchId'] ?? json['match_id']),
      homeTeam: _asString(
        homeTeamMap?['name'] ?? json['homeTeamName'] ?? json['home_team'] ?? json['homeName'],
        fallback: 'Time A',
      ),
      awayTeam: _asString(
        awayTeamMap?['name'] ?? json['awayTeamName'] ?? json['away_team'] ?? json['awayName'],
        fallback: 'Time B',
      ),
      homeFlag: _asString(
        homeTeamMap?['flagUrl'] ?? json['homeFlag'] ?? json['home_flag'],
        fallback: '🏳',
      ),
      awayFlag: _asString(
        awayTeamMap?['flagUrl'] ?? json['awayFlag'] ?? json['away_flag'],
        fallback: '🏳',
      ),
      matchDate: date,
      phase: _phaseLabel(_asString(json['phase'] ?? json['round'] ?? json['stage'], fallback: 'GROUP_STAGE')),
      groupCode: _asStringNullable(json['groupCode'] ?? json['group_code'] ?? json['group']),
      isLocked: apiLocked || timeLocked,
      officialHomeScore: _asInt(
        resultMap?['homeScore'] ??
            json['homeScore'] ??
            json['home_score'] ??
            json['officialHomeScore'],
      ),
      officialAwayScore: _asInt(
        resultMap?['awayScore'] ??
            json['awayScore'] ??
            json['away_score'] ??
            json['officialAwayScore'],
      ),
    );
  }
}

String _phaseLabel(String raw) {
  switch (raw.trim().toUpperCase()) {
    case 'GROUP_STAGE':
      return 'Fase de Grupos';
    case 'SECOND_ROUND':
      return '2ª Fase';
    case 'ROUND_OF_16':
      return 'Oitavas de Final';
    case 'QUARTER_FINAL':
      return 'Quartas de Final';
    case 'SEMI_FINAL':
      return 'Semifinal';
    case 'THIRD_PLACE':
      return 'Terceiro Lugar';
    case 'FINAL':
      return 'Final';
    default:
      return raw.isEmpty ? 'Fase de Grupos' : raw;
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

String? _asStringNullable(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}


