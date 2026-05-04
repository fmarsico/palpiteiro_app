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
      Uri.parse('${ApiConfig.baseUrl}/pool/$poolId/matches'),
      headers: _authHeader(token),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final list = body is List ? body : (body['matches'] ?? body['data'] ?? []);
      return (list as List)
          .map((e) => Match.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    _throwFromBody(response.body, 'Erro ao carregar partidas');
  }

  // ─── Guesses ────────────────────────────────────────────────────────────────

  Future<List<Guess>> getGuesses({
    required String poolId,
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/pool/$poolId/guesses'),
      headers: _authHeader(token),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final list = body is List ? body : (body['guesses'] ?? body['data'] ?? []);
      return (list as List)
          .map((e) => Guess.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    // 404 means no guesses yet — return empty
    if (response.statusCode == 404) return [];
    _throwFromBody(response.body, 'Erro ao carregar palpites');
  }

  Future<void> saveGuesses({
    required String poolId,
    required List<Guess> guesses,
    required String token,
  }) async {
    final body =
        jsonEncode(guesses.map((g) => g.toJson()).toList());
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/pool/$poolId/guesses'),
      headers: _authHeader(token),
      body: body,
    );
    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      _throwFromBody(response.body, 'Erro ao salvar palpites');
    }
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
      final list =
          body is List ? body : (body['ranking'] ?? body['data'] ?? []);
      return List<RankingEntry>.generate(
        (list as List).length,
        (i) => RankingEntry.fromJson(list[i] as Map<String, dynamic>, i + 1),
      );
    }
    _throwFromBody(response.body, 'Erro ao carregar ranking');
  }

  // ─── Members ─────────────────────────────────────────────────────────────────

  Future<({List<PoolMember> members, List<PoolMember> pending})> getMembers({
    required String poolId,
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/pool/$poolId/members'),
      headers: _authHeader(token),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);

      // Format A: { members: [...], pendingRequests: [...] }
      if (body is Map<String, dynamic> &&
          (body.containsKey('members') ||
              body.containsKey('pendingRequests'))) {
        final membersList =
            (body['members'] ?? body['approvedMembers'] ?? []) as List;
        final pendingList =
            (body['pendingRequests'] ?? body['pending'] ?? []) as List;

        final members = membersList
            .map((e) => PoolMember.fromJson(e as Map<String, dynamic>))
            .toList();
        final pending = pendingList
            .map((e) => PoolMember.fromJson(e as Map<String, dynamic>))
            .toList();
        return (members: members, pending: pending);
      }

      // Format B: flat array with status field
      final list = body is List ? body : (body['data'] ?? []);
      final all = (list as List)
          .map((e) => PoolMember.fromJson(e as Map<String, dynamic>))
          .toList();
      final members = all.where((m) => !m.isPending).toList();
      final pending = all.where((m) => m.isPending).toList();
      return (members: members, pending: pending);
    }
    _throwFromBody(response.body, 'Erro ao carregar membros');
  }

  Future<void> approveRequest({
    required String poolId,
    required String requesterId,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/pool/$poolId/approve-request/$requesterId'),
      headers: _authHeader(token),
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
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/pool/$poolId/reject-request/$requesterId'),
      headers: _authHeader(token),
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
  }) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/pool/$poolId/members/$memberId'),
      headers: _authHeader(token),
    );
    if (response.statusCode != 200 &&
        response.statusCode != 204) {
      _throwFromBody(response.body, 'Erro ao remover membro');
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

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
}

