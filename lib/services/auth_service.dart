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

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final result = AuthResult.fromJson(data);
      await _saveSession(result);
      return result;
    } else {
      throw Exception(data['message'] ?? 'Erro ao fazer login');
    }
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

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201 || response.statusCode == 200) {
      final result = AuthResult.fromJson(data);
      await _saveSession(result);
      return result;
    } else {
      throw Exception(data['message'] ?? 'Erro ao criar conta');
    }
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
}
