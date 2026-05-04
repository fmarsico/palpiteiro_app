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
    final role = json['role'] as String? ?? '';
    final statusStr = json['status'] as String? ?? 'approved';
    return PoolMember(
      userId: (json['userId'] ?? json['user_id'] ?? json['id'] ?? '') as String,
      name: (json['name'] ?? json['userName'] ?? json['user_name'] ?? '') as String,
      isOwner: role == 'owner' || role == 'OWNER' || json['isOwner'] == true,
      status: statusStr == 'pending' || statusStr == 'PENDING'
          ? MemberStatus.pending
          : MemberStatus.approved,
    );
  }
}

