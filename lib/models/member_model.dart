enum MemberStatus { approved, pending }

class PoolMember {
  final String userId;
  final String name;
  final bool isOwner;
  final MemberStatus status;

  const PoolMember({
    required this.userId,
    required this.name,
    required this.isOwner,
    required this.status,
  });

  bool get isPending => status == MemberStatus.pending;

  factory PoolMember.fromJson(Map<String, dynamic> json) {
    final nestedUser = json['user'];
    final userMap = nestedUser is Map<String, dynamic> ? nestedUser : null;

    final role = _asString(
      json['role'] ?? json['memberRole'] ?? userMap?['role'],
    ).toLowerCase();

    final statusStr = _asString(
      json['status'] ?? json['requestStatus'] ?? json['membershipStatus'],
      fallback: 'approved',
    ).toLowerCase();

    return PoolMember(
      userId: _asString(
        json['userId'] ??
            json['user_id'] ??
            json['memberId'] ??
            json['requesterId'] ??
            json['id'] ??
            userMap?['id'] ??
            userMap?['userId'],
      ),
      name: _asString(
        json['name'] ??
            json['userName'] ??
            json['user_name'] ??
            json['fullName'] ??
            userMap?['name'] ??
            userMap?['userName'] ??
            userMap?['fullName'],
        fallback: 'Usuario',
      ),
      isOwner: role == 'owner' ||
          role == 'admin' ||
          role == 'creator' ||
          json['isOwner'] == true,
      status: _isPendingStatus(statusStr)
          ? MemberStatus.pending
          : MemberStatus.approved,
    );
  }

  static bool _isPendingStatus(String status) {
    return status.contains('pend') ||
        status.contains('request') ||
        status.contains('aguard');
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }
    return value.toString();
  }
}

