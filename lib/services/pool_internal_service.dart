import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../models/match_model.dart';
import '../models/ranking_model.dart';
import '../models/member_model.dart';

class PoolInternalService {
  Map<String, String> _authHeader(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ─── Matches ────────────────────────────────────────────────────────────────

  Future<List<Match>> getMatches({
    required String poolId,
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/match'),
      headers: _authHeader(token),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final list = _extractListPayload(body, preferredKeys: const ['matches']);
      return list
          .whereType<Map<String, dynamic>>()
          .map(Match.fromJson)
          .toList();
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      _throwFromBody(response.body, 'Sessao expirada. Faca login novamente.');
    }

    _throwFromBody(response.body, 'Erro ao carregar partidas');
  }

  // ─── Guesses ────────────────────────────────────────────────────────────────

  Future<List<Guess>> getGuesses({
    required String poolId,
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/pool/$poolId/predictions/me'),
      headers: _authHeader(token),
    );

    if (response.statusCode == 200) {
      final body = response.body.trim().isEmpty ? const <dynamic>[] : jsonDecode(response.body);
      final list = _extractListPayload(body, preferredKeys: const ['predictions']);
      return list
          .whereType<Map<String, dynamic>>()
          .map(Guess.fromJson)
          .toList();
    }

    if (response.statusCode == 404) return const <Guess>[];
    if (response.statusCode == 401 || response.statusCode == 403) {
      _throwFromBody(response.body, 'Sessao expirada. Faca login novamente.');
    }

    _throwFromBody(response.body, 'Erro ao carregar palpites');
  }

  Future<List<Guess>> saveGuesses({
    required String poolId,
    required String userId,
    required List<Guess> guesses,
    required String token,
  }) async {
    final payload = jsonEncode({
      'userId': userId,
      'poolId': poolId,
      'predictions': guesses.map((g) => g.toJson()).toList(),
    });

    Future<http.Response> send(bool update) {
      return update
          ? http.put(
              Uri.parse('${ApiConfig.baseUrl}/prediction'),
              headers: _authHeader(token),
              body: payload,
            )
          : http.post(
              Uri.parse('${ApiConfig.baseUrl}/prediction'),
              headers: _authHeader(token),
              body: payload,
            );
    }

    var response = await send(false);
    if (response.statusCode == 400) {
      final message = _responseMessage(response.body).toLowerCase();
      if (message.contains('already exists') ||
          message.contains('ja existe') ||
          message.contains('já existe')) {
        response = await send(true);
      }
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      _throwFromBody(response.body, 'Erro ao salvar palpites');
    }

    final body = response.body.trim().isEmpty ? const <dynamic>[] : jsonDecode(response.body);
    final list = _extractListPayload(body, preferredKeys: const ['predictions']);
    return list
        .whereType<Map<String, dynamic>>()
        .map(Guess.fromJson)
        .toList();
  }

  // ─── Ranking ─────────────────────────────────────────────────────────────────

  Future<List<RankingEntry>> getRanking({
    required String poolId,
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/pool/$poolId/ranking'),
      headers: _authHeader(token),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final list = _extractListPayload(body, preferredKeys: const ['ranking']);
      return List<RankingEntry>.generate(
        list.length,
        (i) => RankingEntry.fromJson(list[i] as Map<String, dynamic>, i + 1),
      );
    }
    _throwFromBody(response.body, 'Erro ao carregar ranking');
  }

  // ─── Members ─────────────────────────────────────────────────────────────────

  Future<({List<PoolMember> members, List<PoolMember> pending})> getMembers({
    required String poolId,
    required String token,
    String? ownerId,
  }) async {
    final members = <PoolMember>[];
    final pending = <PoolMember>[];

    // If we are the owner, the memberships endpoint returns owner + all statuses.
    if (ownerId != null && ownerId.isNotEmpty) {
      final membershipsPayload = await _getOptional(
        path: '/pool/$poolId/memberships?ownerId=$ownerId',
        token: token,
      );
      if (membershipsPayload != null) {
        final parsed = _parseMembershipsPayload(
          membershipsPayload,
          ownerId: ownerId,
        );
        if (parsed.members.isNotEmpty || parsed.pending.isNotEmpty) {
          return (
            members: _uniqueMembersById(parsed.members),
            pending: _uniqueMembersById(parsed.pending),
          );
        }
      }
    }

    // First, fetch approved members (always from /pool/{poolId}/members)
    final membersPayload = await _getOptional(
      path: '/pool/$poolId/members',
      token: token,
    );
    if (membersPayload != null) {
      final parsed = _parseMembersPayload(membersPayload);
      members.addAll(parsed.members);
    }

    // If direct members endpoint is unavailable for this user, try member-of.
    if (members.isEmpty && ownerId != null && ownerId.isNotEmpty) {
      final memberOfPayload = await _getOptional(
        path: '/pool/member-of/$ownerId/members',
        token: token,
      );
      if (memberOfPayload != null) {
        members.addAll(
          _parseMemberOfMembersPayload(memberOfPayload, poolId: poolId),
        );
      }
    }

    // Then fetch pending requests (requires ownerId)
    if (ownerId != null && ownerId.isNotEmpty) {
      final pendingPayload = await _getOptional(
        path: '/pool/$poolId/pending-requests?ownerId=$ownerId',
        token: token,
      );
      if (pendingPayload != null) {
        final parsed = _parseMembersPayload(pendingPayload);
        pending.addAll(parsed.pending);
        // If payload contains pending items but they're marked as approved, convert them
        pending.addAll(parsed.members.where((m) => m.isPending));
      }
    }

    return (
      members: _uniqueMembersById(members.where((m) => !m.isPending).toList()),
      pending: _uniqueMembersById(pending.where((m) => m.isPending).toList()),
    );
  }

  ({List<PoolMember> members, List<PoolMember> pending}) _parseMembershipsPayload(
    dynamic payload, {
    required String ownerId,
  }) {
    final members = <PoolMember>[];
    final pending = <PoolMember>[];

    final rows = _extractListPayload(
      payload,
      preferredKeys: const ['memberships'],
    );

    for (final item in rows.whereType<Map<String, dynamic>>()) {
      final member = PoolMember.fromJson(item);
      final normalized = PoolMember(
        userId: member.userId,
        name: member.name,
        isOwner: member.userId == ownerId || member.isOwner,
        status: member.status,
      );

      if (normalized.isPending) {
        pending.add(normalized);
      } else {
        members.add(normalized);
      }
    }

    return (members: members, pending: pending);
  }

  Future<void> approveRequest({
    required String poolId,
    required String requesterId,
    required String token,
    required String ownerId,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/pool/$poolId/approve-member?ownerId=$ownerId'),
      headers: _authHeader(token),
      body: jsonEncode({'userId': requesterId}),
    );
    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      _throwFromBody(response.body, 'Erro ao aprovar solicitação');
    }
  }

  Future<void> rejectRequest({
    required String poolId,
    required String requesterId,
    required String token,
    required String ownerId,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/pool/$poolId/reject-member?ownerId=$ownerId'),
      headers: _authHeader(token),
      body: jsonEncode({'userId': requesterId}),
    );
    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      _throwFromBody(response.body, 'Erro ao rejeitar solicitação');
    }
  }

  Future<void> removeMember({
    required String poolId,
    required String memberId,
    required String token,
    required String ownerId,
  }) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/pool/$poolId/members/$memberId?ownerId=$ownerId'),
      headers: _authHeader(token),
    );
    if (response.statusCode != 200 &&
        response.statusCode != 204) {
      _throwFromBody(response.body, 'Erro ao remover membro');
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Future<dynamic> _getOptional({
    required String path,
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _authHeader(token),
    );
    if (response.statusCode == 200) {
      if (response.body.trim().isEmpty) return const <dynamic>[];
      return jsonDecode(response.body);
    }
    if (response.statusCode == 404) return null;
    if (response.statusCode == 401) {
      _throwFromBody(response.body, 'Sessao expirada. Faca login novamente.');
    }
    // 403 can happen on role-restricted routes; let callers try fallback endpoints.
    if (response.statusCode == 403) return null;
    return null;
  }

  Future<dynamic> _getRequired({
    required String path,
    required String token,
    required String fallback,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _authHeader(token),
    );
    if (response.statusCode == 200) {
      if (response.body.trim().isEmpty) return const <dynamic>[];
      return jsonDecode(response.body);
    }
    _throwFromBody(response.body, fallback);
  }

  List<dynamic> _extractListPayload(
    dynamic body, {
    List<String> preferredKeys = const <String>[],
  }) {
    if (body is List) return body;
    if (body is! Map<String, dynamic>) return const <dynamic>[];

    for (final key in preferredKeys) {
      final value = body[key];
      if (value is List) return value;
    }

    // Common wrappers used by Spring/Page and custom APIs.
    final commonKeys = <String>['content', 'data', 'items', 'results', 'rows'];
    for (final key in commonKeys) {
      final value = body[key];
      if (value is List) return value;
    }

    return const <dynamic>[];
  }

  ({List<PoolMember> members, List<PoolMember> pending}) _parseMembersPayload(
    dynamic payload,
  ) {
    final members = <PoolMember>[];
    final pending = <PoolMember>[];

    if (payload is Map<String, dynamic>) {
      final membersRaw = payload['members'] ??
          payload['approvedMembers'] ??
          payload['participants'] ??
          payload['users'] ??
          payload['items'];
      final pendingRaw = payload['pendingRequests'] ??
          payload['pending'] ??
          payload['requests'] ??
          payload['joinRequests'];

      if (membersRaw is List) {
        members.addAll(
          membersRaw
              .whereType<Map<String, dynamic>>()
              .map(PoolMember.fromJson)
              .map((m) => m.isPending
                  ? PoolMember(
                      userId: m.userId,
                      name: m.name,
                      isOwner: m.isOwner,
                      status: MemberStatus.approved,
                    )
                  : m),
        );
      }
      if (pendingRaw is List) {
        pending.addAll(
          pendingRaw
              .whereType<Map<String, dynamic>>()
              .map(PoolMember.fromJson)
              .map((m) => m.isPending
                  ? m
                  : PoolMember(
                      userId: m.userId,
                      name: m.name,
                      isOwner: m.isOwner,
                      status: MemberStatus.pending,
                    )),
        );
      }

      // Alguns backends usam apenas payload['data'] como lista plana.
      final dataRaw = payload['data'];
      if (dataRaw is List && members.isEmpty && pending.isEmpty) {
        final all = dataRaw
            .whereType<Map<String, dynamic>>()
            .map(PoolMember.fromJson)
            .toList();
        members.addAll(all.where((m) => !m.isPending));
        pending.addAll(all.where((m) => m.isPending));
      }
    } else if (payload is List) {
      final all = payload
          .whereType<Map<String, dynamic>>()
          .map(PoolMember.fromJson)
          .toList();
      members.addAll(all.where((m) => !m.isPending));
      pending.addAll(all.where((m) => m.isPending));
    }

    return (members: members, pending: pending);
  }

  List<PoolMember> _parseMemberOfMembersPayload(
    dynamic payload, {
    required String poolId,
  }) {
    final rows = <Map<String, dynamic>>[];

    void collectFromList(List<dynamic> list) {
      for (final item in list.whereType<Map<String, dynamic>>()) {
        final nestedMembers = item['members'];
        final hasPoolContext = _extractPoolId(item) != null;

        if (nestedMembers is List) {
          if (_matchesPool(item, poolId)) {
            rows.addAll(nestedMembers.whereType<Map<String, dynamic>>());
          }
          continue;
        }

        // Flat shape. If pool is informed, only keep current pool.
        if (!hasPoolContext || _matchesPool(item, poolId)) {
          rows.add(item);
        }
      }
    }

    if (payload is List) {
      collectFromList(payload);
    } else if (payload is Map<String, dynamic>) {
      final membersRaw = payload['members'];
      if (membersRaw is List) {
        if (_matchesPool(payload, poolId) || _extractPoolId(payload) == null) {
          collectFromList(membersRaw);
        }
      }
      final dataRaw = payload['data'];
      if (dataRaw is List) {
        collectFromList(dataRaw);
      }
      final itemsRaw = payload['items'];
      if (itemsRaw is List) {
        collectFromList(itemsRaw);
      }
    }

    return rows
        .map(PoolMember.fromJson)
        .where((m) => !m.isPending)
        .toList();
  }

  bool _matchesPool(Map<String, dynamic> entry, String poolId) {
    final extracted = _extractPoolId(entry);
    if (extracted == null || extracted.isEmpty) return true;
    return extracted == poolId;
  }

  String? _extractPoolId(Map<String, dynamic> entry) {
    final direct = entry['poolId'] ?? entry['pool_id'];
    if (direct is String && direct.trim().isNotEmpty) return direct;

    final nestedPool = entry['pool'];
    if (nestedPool is Map<String, dynamic>) {
      final nestedId = nestedPool['id'] ?? nestedPool['poolId'];
      if (nestedId is String && nestedId.trim().isNotEmpty) return nestedId;
    }

    return null;
  }

  List<PoolMember> _uniqueMembersById(List<PoolMember> source) {
    final byId = <String, PoolMember>{};
    for (final item in source) {
      final key = item.userId.trim().isEmpty ? item.name : item.userId;
      byId[key] = item;
    }
    return byId.values.toList();
  }

  Never _throwFromBody(String body, String fallback) {
    String? message;
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final msg = data['message'];
        if (msg is String && msg.trim().isNotEmpty) message = msg;
      }
    } catch (_) {}
    throw Exception(message ?? fallback);
  }

  String _responseMessage(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final msg = data['message'];
        if (msg is String && msg.trim().isNotEmpty) return msg;
      }
    } catch (_) {}
    return body;
  }
}

