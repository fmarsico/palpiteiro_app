class Pool {
  final String id;
  final String name;
  final String inviteCode;
  final String ownerId;

  const Pool({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerId,
  });

  factory Pool.fromJson(Map<String, dynamic> json) => Pool(
        id: json['id'] as String,
        name: json['name'] as String,
        inviteCode: json['inviteCode'] as String,
        ownerId: json['ownerId'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'inviteCode': inviteCode,
        'ownerId': ownerId,
      };
}

