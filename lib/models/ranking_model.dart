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

  factory RankingEntry.fromJson(Map<String, dynamic> json, int position) =>
      RankingEntry(
        userId: (json['userId'] ?? json['user_id'] ?? json['id'] ?? '') as String,
        name: (json['name'] ?? json['userName'] ?? json['user_name'] ?? '') as String,
        position: json['position'] as int? ?? json['rank'] as int? ?? position,
        points: json['points'] as int? ?? json['totalPoints'] as int? ?? 0,
        exactGuesses:
            json['exactGuesses'] as int? ?? json['exact'] as int? ?? 0,
        groupPoints:
            json['groupPoints'] as int? ?? json['group'] as int? ?? 0,
        knockoutPoints:
            json['knockoutPoints'] as int? ?? json['knockout'] as int? ?? 0,
      );
}

