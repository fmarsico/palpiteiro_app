import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_config.dart';

class AuthResult {
  final String token;
  final String userId;
  final String name;
  final String email;

  const AuthResult({
    required this.token,
    required this.userId,
    required this.name,
    required this.email,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        token: json['token'] as String,
        userId: json['userId'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
      );
}

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';

  Map<String, String> _authHeader(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<void> updateStoredProfile({
    String? name,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (name != null) {
      await prefs.setString(_userNameKey, name);
    }

    if (email != null) {
      await prefs.setString(_userEmailKey, email);
    }
  }

  Future<AuthResult> updateProfile({
    required String token,
    required String name,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getString(_userIdKey);

    final body = jsonEncode({
      'name': name,
      'email': email,
    });

    final request = http.Request(
      'PUT',
      Uri.parse('${ApiConfig.baseUrl}/user'),
    )
      ..headers.addAll(_authHeader(token))
      ..body = body;

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final parsedBody = _tryParseJson(response.body);

    if (response.statusCode == 200 ||
        response.statusCode == 201 ||
        response.statusCode == 204) {
      final result = _authResultFromUpdateResponse(
        parsedBody,
        fallbackToken: token,
        fallbackUserId: storedUserId ?? '',
        fallbackName: name,
        fallbackEmail: email,
      );
      await _saveSession(result);
      return result;
    }

    throw Exception(_extractMessage(parsedBody) ?? 'Erro ao atualizar perfil');
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final payload = _tryParseJson(response.body);

    if (response.statusCode == 200) {
      final result = _authResultFromAuthPayload(payload);
      await _saveSession(result);
      return result;
    }

    throw Exception(_extractMessage(payload) ?? 'Erro ao fazer login');
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    String? favoriteTeam,
    bool notifications = true,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        if (favoriteTeam != null) 'favoriteTeam': favoriteTeam,
        'notifications': notifications,
      }),
    );

    final payload = _tryParseJson(response.body);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final result = _authResultFromAuthPayload(payload);
      await _saveSession(result);
      return result;
    }

    throw Exception(_extractMessage(payload) ?? 'Erro ao criar conta');
  }

  Future<void> _saveSession(AuthResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, result.token);
    await prefs.setString(_userIdKey, result.userId);
    await prefs.setString(_userNameKey, result.name);
    await prefs.setString(_userEmailKey, result.email);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
  }

  Object? _tryParseJson(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  String? _extractMessage(Object? payload) {
    if (payload is Map<String, dynamic>) {
      final message = payload['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    if (payload is String && payload.trim().isNotEmpty) {
      return payload;
    }

    return null;
  }

  AuthResult _authResultFromUpdateResponse(
    Object? payload, {
    required String fallbackToken,
    required String fallbackUserId,
    required String fallbackName,
    required String fallbackEmail,
  }) {
    final root = payload is Map<String, dynamic> ? payload : <String, dynamic>{};
    final nestedUser = root['user'];
    final user = nestedUser is Map<String, dynamic> ? nestedUser : root;

    final token = (root['token'] ?? user['token']) as String? ?? fallbackToken;
    final userId = (root['userId'] ?? user['userId'] ?? user['id']) as String? ??
        fallbackUserId;
    final name = (root['name'] ?? user['name']) as String? ?? fallbackName;
    final email = (root['email'] ?? user['email']) as String? ?? fallbackEmail;

    if (userId.trim().isEmpty) {
      throw Exception('Resposta da API sem userId');
    }

    return AuthResult(
      token: token,
      userId: userId,
      name: name,
      email: email,
    );
  }

  AuthResult _authResultFromAuthPayload(Object? payload) {
    if (payload is! Map<String, dynamic>) {
      throw Exception('Resposta da API em formato inesperado');
    }

    final nestedUser = payload['user'];
    final user = nestedUser is Map<String, dynamic> ? nestedUser : payload;

    final token = payload['token'] as String?;
    final userId = (payload['userId'] ?? user['userId'] ?? user['id']) as String?;
    final name = (payload['name'] ?? user['name']) as String?;
    final email = (payload['email'] ?? user['email']) as String?;

    if (token == null ||
        token.trim().isEmpty ||
        userId == null ||
        userId.trim().isEmpty ||
        name == null ||
        name.trim().isEmpty ||
        email == null ||
        email.trim().isEmpty) {
      throw Exception('Resposta da API em formato inesperado');
    }

    return AuthResult(
      token: token,
      userId: userId,
      name: name,
      email: email,
    );
  }
}
