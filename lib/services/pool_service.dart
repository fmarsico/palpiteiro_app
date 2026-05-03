import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../models/pool_model.dart';

class PoolService {
  Map<String, String> _authHeader(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<List<Pool>> getOwnedPools({
    required String userId,
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/pool/owned-by/$userId'),
      headers: _authHeader(token),
    );
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((e) => Pool.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Erro ao carregar bolões');
  }

  Future<Pool> createPool({
    required String name,
    required String ownerId,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/pool'),
      headers: _authHeader(token),
      body: jsonEncode({'name': name, 'ownerId': ownerId}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Pool.fromJson(data);
    }
    throw Exception(data['message'] ?? 'Erro ao criar bolão');
  }

  Future<Pool> findByInviteCode({
    required String inviteCode,
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/pool/invite/$inviteCode'),
      headers: _authHeader(token),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return Pool.fromJson(data);
    }
    throw Exception(data['message'] ?? 'Bolão não encontrado');
  }

  Future<void> requestAccess({
    required String poolId,
    required String userId,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/pool/$poolId/request-access'),
      headers: _authHeader(token),
      body: jsonEncode({'userId': userId}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(data['message'] ?? 'Erro ao solicitar acesso');
    }
  }
}

