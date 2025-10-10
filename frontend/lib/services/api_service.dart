import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// API 서비스
/// 백엔드 API와의 통신을 담당합니다.
class ApiService {
  // 서버 주소
  static const String baseUrl = 'http://192.168.219.101:8989';

  // API 엔드포인트
  static const String _installEndpoint = '/litten/note/v1/members/install';
  static const String _signUpEndpoint = '/litten/note/v1/members/signup';
  static const String _loginWebEndpoint = '/litten/note/v1/members/login/web';
  static const String _loginMobileEndpoint =
      '/litten/note/v1/members/login/mobile';
  static const String _passwordUrlEndpoint =
      '/litten/note/v1/members/password-url';
  static const String _passwordEndpoint = '/litten/note/v1/members/password';
  static const String _membersEndpoint = '/litten/note/v1/members';

  /// HTTP 헤더 생성
  Map<String, String> _getHeaders({String? token}) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['auth-token'] = token;
    }
    return headers;
  }

  /// UUID 등록 (처음 설치 시)
  /// POST /litten/note/v1/members/install
  /// {"uuid": "sdajf-asdjfls-02394iowjfi-sadj1"}
  /// Response: {"result": 1} (1=성공, 기타=실패)
  Future<Map<String, dynamic>> registerUuid({required String uuid}) async {
    debugPrint('[ApiService] registerUuid - uuid: $uuid');

    try {
      final url = Uri.parse('$baseUrl$_installEndpoint');
      final body = jsonEncode({'uuid': uuid});

      debugPrint('[ApiService] registerUuid - URL: $url');
      debugPrint('[ApiService] registerUuid - Request body: $body');

      final response = await http.post(url, headers: _getHeaders(), body: body);

      debugPrint(
        '[ApiService] registerUuid - Response status: ${response.statusCode}',
      );
      debugPrint('[ApiService] registerUuid - Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = data['result'] as int?;
        final message = data['message'] as String?;

        if (result == 1) {
          debugPrint('[ApiService] registerUuid - Success');
          return data;
        } else {
          final errorMsg = message != null
              ? 'UUID 등록 실패: result=$result, message=$message'
              : 'UUID 등록 실패: result=$result';
          debugPrint('[ApiService] registerUuid - Failed: $errorMsg');
          throw Exception(errorMsg);
        }
      } else {
        debugPrint(
          '[ApiService] registerUuid - Failed: ${response.statusCode}',
        );
        throw Exception('UUID 등록 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] registerUuid - Error: $e');
      rethrow;
    }
  }

  /// 회원가입
  /// POST /litten/note/v1/members/signup
  /// {"id": "bgso777@naver.com", "password": "asdf", "uuid": "sdajf-asdjfls-02394iowjfi-sadj1"}
  /// Response: {"result": 1} (1=성공, 기타=실패)
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String uuid,
  }) async {
    debugPrint('[ApiService] signUp - email: $email, uuid: $uuid');

    try {
      final url = Uri.parse('$baseUrl$_signUpEndpoint');
      final body = jsonEncode({
        'id': email,
        'password': password,
        'uuid': uuid,
      });

      debugPrint('[ApiService] signUp - URL: $url');
      debugPrint('[ApiService] signUp - Request body: $body');

      final response = await http.post(url, headers: _getHeaders(), body: body);

      debugPrint(
        '[ApiService] signUp - Response status: ${response.statusCode}',
      );
      debugPrint('[ApiService] signUp - Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = data['result'] as int?;
        final message = data['message'] as String?;

        if (result == 1) {
          debugPrint('[ApiService] signUp - Success');
          return data;
        } else {
          final errorMsg = message != null
              ? '회원가입 실패: result=$result, message=$message'
              : '회원가입 실패: result=$result';
          debugPrint('[ApiService] signUp - Failed: $errorMsg');
          throw Exception(errorMsg);
        }
      } else {
        debugPrint('[ApiService] signUp - Failed: ${response.statusCode}');
        throw Exception('회원가입 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] signUp - Error: $e');
      rethrow;
    }
  }

  /// 로그인 (웹)
  /// POST /litten/note/v1/members/login/web
  /// {"id":"id@domain","password":"password1234"}
  /// Response: {"result": 1, "token": "...", "userId": "..."} (1=성공, 기타=실패)
  Future<Map<String, dynamic>> loginWeb({
    required String email,
    required String password,
  }) async {
    debugPrint('[ApiService] loginWeb - email: $email');

    try {
      final url = Uri.parse('$baseUrl$_loginWebEndpoint');
      final body = jsonEncode({'id': email, 'password': password});

      debugPrint('[ApiService] loginWeb - URL: $url');
      debugPrint('[ApiService] loginWeb - Request body: $body');

      final response = await http.post(url, headers: _getHeaders(), body: body);

      debugPrint(
        '[ApiService] loginWeb - Response status: ${response.statusCode}',
      );
      debugPrint('[ApiService] loginWeb - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = data['result'] as int?;
        final message = data['message'] as String?;

        if (result == 1) {
          debugPrint('[ApiService] loginWeb - Success');
          return data;
        } else {
          final errorMsg = message != null
              ? '로그인 실패: result=$result, message=$message'
              : '로그인 실패: result=$result';
          debugPrint('[ApiService] loginWeb - Failed: $errorMsg');
          throw Exception(errorMsg);
        }
      } else {
        debugPrint('[ApiService] loginWeb - Failed: ${response.statusCode}');
        throw Exception('로그인 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] loginWeb - Error: $e');
      rethrow;
    }
  }

  /// 로그인 (모바일)
  /// POST /litten/note/v1/members/login/mobile
  /// {"id":"id@domain","password":"password1234"}
  /// Response: {"result": 1, "token": "...", "userId": "..."} (1=성공, 기타=실패)
  Future<Map<String, dynamic>> loginMobile({
    required String email,
    required String password,
    required String uuid,
  }) async {
    debugPrint('[ApiService] loginMobile - email: $email, uuid: $uuid');

    try {
      final url = Uri.parse('$baseUrl$_loginMobileEndpoint');
      final body = jsonEncode({
        'id': email,
        'password': password,
        'uuid': uuid,
      });

      debugPrint('[ApiService] loginMobile - URL: $url');
      debugPrint('[ApiService] loginMobile - Request body: $body');

      final response = await http.post(url, headers: _getHeaders(), body: body);

      debugPrint(
        '[ApiService] loginMobile - Response status: ${response.statusCode}',
      );
      debugPrint('[ApiService] loginMobile - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = data['result'] as int?;
        final message = data['message'] as String?;

        if (result == 1) {
          debugPrint('[ApiService] loginMobile - Success');
          return data;
        } else {
          final errorMsg = message != null
              ? '로그인 실패: result=$result, message=$message'
              : '로그인 실패: result=$result';
          debugPrint('[ApiService] loginMobile - Failed: $errorMsg');
          throw Exception(errorMsg);
        }
      } else {
        debugPrint('[ApiService] loginMobile - Failed: ${response.statusCode}');
        throw Exception('로그인 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] loginMobile - Error: $e');
      rethrow;
    }
  }

  /// 로그인 (하위 호환성 - 모바일 로그인 사용)
  /// POST /litten/note/v1/members/login/mobile
  /// {"id":"id@domain","password":"password1234","uuid":"device-uuid"}
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String uuid,
  }) async {
    return loginMobile(email: email, password: password, uuid: uuid);
  }

  /// 비밀번호 재발급 URL 전송
  /// POST /litten/note/v1/members/password-url
  /// {"id":"id@domain"}
  /// Response: {"result": 1} (1=성공, 기타=실패)
  Future<void> sendPasswordResetEmail({required String email}) async {
    debugPrint('[ApiService] sendPasswordResetEmail - email: $email');

    try {
      final url = Uri.parse('$baseUrl$_passwordUrlEndpoint');
      final body = jsonEncode({'id': email});

      debugPrint('[ApiService] sendPasswordResetEmail - URL: $url');
      debugPrint('[ApiService] sendPasswordResetEmail - Request body: $body');

      final response = await http.post(url, headers: _getHeaders(), body: body);

      debugPrint(
        '[ApiService] sendPasswordResetEmail - Response status: ${response.statusCode}',
      );
      debugPrint(
        '[ApiService] sendPasswordResetEmail - Response body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = data['result'] as int?;
        final message = data['message'] as String?;

        if (result == 1) {
          debugPrint('[ApiService] sendPasswordResetEmail - Success');
          return;
        } else {
          final errorMsg = message != null
              ? '비밀번호 재발급 이메일 전송 실패: result=$result, message=$message'
              : '비밀번호 재발급 이메일 전송 실패: result=$result';
          debugPrint('[ApiService] sendPasswordResetEmail - Failed: $errorMsg');
          throw Exception(errorMsg);
        }
      } else {
        debugPrint(
          '[ApiService] sendPasswordResetEmail - Failed: ${response.statusCode}',
        );
        throw Exception('비밀번호 재발급 이메일 전송 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] sendPasswordResetEmail - Error: $e');
      rethrow;
    }
  }

  /// 비밀번호 변경
  /// PUT /litten/note/v1/members/password
  /// {"id":"id@domain","password":"password1234","newPassword":"password1234"}
  /// Response: {"result": 1} (1=성공, 기타=실패)
  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
    String? token,
  }) async {
    debugPrint('[ApiService] changePassword - email: $email');

    try {
      final url = Uri.parse('$baseUrl$_passwordEndpoint');
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

      debugPrint(
        '[ApiService] changePassword - Response status: ${response.statusCode}',
      );
      debugPrint(
        '[ApiService] changePassword - Response body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = data['result'] as int?;
        final message = data['message'] as String?;

        if (result == 1) {
          debugPrint('[ApiService] changePassword - Success');
          return;
        } else {
          final errorMsg = message != null
              ? '비밀번호 변경 실패: result=$result, message=$message'
              : '비밀번호 변경 실패: result=$result';
          debugPrint('[ApiService] changePassword - Failed: $errorMsg');
          throw Exception(errorMsg);
        }
      } else {
        debugPrint(
          '[ApiService] changePassword - Failed: ${response.statusCode}',
        );
        throw Exception('비밀번호 변경 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] changePassword - Error: $e');
      rethrow;
    }
  }

  /// 회원탈퇴
  /// DELETE /note/v1/members/{id}
  /// Response: {"result": 1} (1=성공, 기타=실패)
  Future<void> deleteAccount({required String email, String? token}) async {
    debugPrint('[ApiService] deleteAccount - email: $email');

    try {
      final url = Uri.parse('$baseUrl$_membersEndpoint/$email');

      debugPrint('[ApiService] deleteAccount - URL: $url');

      final response = await http.delete(
        url,
        headers: _getHeaders(token: token),
      );

      debugPrint(
        '[ApiService] deleteAccount - Response status: ${response.statusCode}',
      );
      debugPrint(
        '[ApiService] deleteAccount - Response body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = data['result'] as int?;
        final message = data['message'] as String?;

        if (result == 1) {
          debugPrint('[ApiService] deleteAccount - Success');
          return;
        } else {
          final errorMsg = message != null
              ? '회원탈퇴 실패: result=$result, message=$message'
              : '회원탈퇴 실패: result=$result';
          debugPrint('[ApiService] deleteAccount - Failed: $errorMsg');
          throw Exception(errorMsg);
        }
      } else {
        debugPrint(
          '[ApiService] deleteAccount - Failed: ${response.statusCode}',
        );
        throw Exception('회원탈퇴 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] deleteAccount - Error: $e');
      rethrow;
    }
  }

  /// UUID로 계정 조회
  /// GET /note/v1/members?uuid={uuid}&state=signup
  /// Response: {"result": 1, "body": {...}} (1=성공/계정있음, 0=계정없음)
  Future<Map<String, dynamic>?> findAccountByUuid({
    required String uuid,
  }) async {
    debugPrint('[ApiService] findAccountByUuid - uuid: $uuid');

    try {
      final url = Uri.parse(
        '$baseUrl$_membersEndpoint?uuid=$uuid&state=signup',
      );

      debugPrint('[ApiService] findAccountByUuid - URL: $url');

      final response = await http.get(url, headers: _getHeaders());

      debugPrint(
        '[ApiService] findAccountByUuid - Response status: ${response.statusCode}',
      );
      debugPrint(
        '[ApiService] findAccountByUuid - Response body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = data['result'] as int?;

        if (result == 1) {
          // 계정 존재
          debugPrint('[ApiService] findAccountByUuid - Account found');
          return data;
        } else {
          // 계정 없음
          debugPrint('[ApiService] findAccountByUuid - Account not found');
          return null;
        }
      } else {
        debugPrint(
          '[ApiService] findAccountByUuid - Failed: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('[ApiService] findAccountByUuid - Error: $e');
      return null;
    }
  }
}
