import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// API 서비스
/// 백엔드 API와의 통신을 담당합니다.
class ApiService {
  // 서버 주소
  static const String baseUrl = 'http://localhost:8989';

  // API 엔드포인트
  static const String _membersEndpoint = '/litten/note/members';
  static const String _loginEndpoint = '/litten/note/members/login';
  static const String _passwordResetEndpoint = '/litten/note/members/password';

  /// HTTP 헤더 생성
  Map<String, String> _getHeaders({String? token}) {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// 회원가입
  /// POST /litten/note/members
  /// {"id":"id@domain","password":"password1234"}
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
  }) async {
    debugPrint('[ApiService] signUp - email: $email');

    try {
      final url = Uri.parse('$baseUrl$_membersEndpoint');
      final body = jsonEncode({
        'id': email,
        'password': password,
      });

      debugPrint('[ApiService] signUp - URL: $url');
      debugPrint('[ApiService] signUp - Request body: $body');

      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: body,
      );

      debugPrint('[ApiService] signUp - Response status: ${response.statusCode}');
      debugPrint('[ApiService] signUp - Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('[ApiService] signUp - Success');
        return data;
      } else {
        debugPrint('[ApiService] signUp - Failed: ${response.statusCode}');
        throw Exception('회원가입 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] signUp - Error: $e');
      rethrow;
    }
  }

  /// 로그인
  /// POST /litten/note/members/login
  /// {"id":"id@domain","password":"password1234"}
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    debugPrint('[ApiService] login - email: $email');

    try {
      final url = Uri.parse('$baseUrl$_loginEndpoint');
      final body = jsonEncode({
        'id': email,
        'password': password,
      });

      debugPrint('[ApiService] login - URL: $url');
      debugPrint('[ApiService] login - Request body: $body');

      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: body,
      );

      debugPrint('[ApiService] login - Response status: ${response.statusCode}');
      debugPrint('[ApiService] login - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[ApiService] login - Success');
        return data;
      } else {
        debugPrint('[ApiService] login - Failed: ${response.statusCode}');
        throw Exception('로그인 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] login - Error: $e');
      rethrow;
    }
  }

  /// 비밀번호 재발급 URL 전송
  /// POST /litten/note/members/password
  /// {"id":"id@domain"}
  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    debugPrint('[ApiService] sendPasswordResetEmail - email: $email');

    try {
      final url = Uri.parse('$baseUrl$_passwordResetEndpoint');
      final body = jsonEncode({
        'id': email,
      });

      debugPrint('[ApiService] sendPasswordResetEmail - URL: $url');
      debugPrint('[ApiService] sendPasswordResetEmail - Request body: $body');

      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: body,
      );

      debugPrint('[ApiService] sendPasswordResetEmail - Response status: ${response.statusCode}');
      debugPrint('[ApiService] sendPasswordResetEmail - Response body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('[ApiService] sendPasswordResetEmail - Success');
        return;
      } else {
        debugPrint('[ApiService] sendPasswordResetEmail - Failed: ${response.statusCode}');
        throw Exception('비밀번호 재발급 이메일 전송 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] sendPasswordResetEmail - Error: $e');
      rethrow;
    }
  }

  /// 비밀번호 변경
  /// PUT /litten/note/members
  /// {"id":"id@domain","password":"password1234","newPassword":"password1234"}
  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
    String? token,
  }) async {
    debugPrint('[ApiService] changePassword - email: $email');

    try {
      final url = Uri.parse('$baseUrl$_membersEndpoint');
      final body = jsonEncode({
        'id': email,
        'password': currentPassword,
        'newPassword': newPassword,
      });

      debugPrint('[ApiService] changePassword - URL: $url');
      debugPrint('[ApiService] changePassword - Request body: $body');

      final response = await http.put(
        url,
        headers: _getHeaders(token: token),
        body: body,
      );

      debugPrint('[ApiService] changePassword - Response status: ${response.statusCode}');
      debugPrint('[ApiService] changePassword - Response body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('[ApiService] changePassword - Success');
        return;
      } else {
        debugPrint('[ApiService] changePassword - Failed: ${response.statusCode}');
        throw Exception('비밀번호 변경 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] changePassword - Error: $e');
      rethrow;
    }
  }
}
