class RankingEntry {
  final String userId;
  final String name;
  final int position;
  final int points;
  final int exactGuesses;
  final int groupPoints;
  final int knockoutPoints;

  const RankingEntry({
	required this.userId,
	required this.name,
	required this.position,
	required this.points,
	required this.exactGuesses,
	required this.groupPoints,
	required this.knockoutPoints,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json, int fallbackPosition) {
	return RankingEntry(
	  userId: _asString(json['userId'] ?? json['user_id'] ?? json['id']),
	  name: _asString(json['name'] ?? json['userName'] ?? json['user_name']),
	  position: _asInt(json['rank'] ?? json['position'], fallback: fallbackPosition),
	  points: _asInt(json['totalPoints'] ?? json['points']),
	  exactGuesses: _asInt(json['exactHitsTotal'] ?? json['exactGuesses'] ?? json['exact']),
	  groupPoints: _asInt(json['exactHitsGroupStage'] ?? json['groupPoints'] ?? json['group']),
	  knockoutPoints: _asInt(json['exactHitsKnockout'] ?? json['knockoutPoints'] ?? json['knockout']),
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

int _asInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

