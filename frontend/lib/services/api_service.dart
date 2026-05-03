import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:flutter/foundation.dart';

/// API 서비스
/// 백엔드 API와의 통신을 담당합니다.
class ApiService {
  // 서버 주소
  static const String baseUrl = 'http://www.litten7.com:8081';

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
  static const String _summaryEndpoint = '/litten/note/v1/summary';
  static const String _myInfoEndpoint = '/litten/note/v1/members/me';
  static const String _planEndpoint = '/litten/note/v1/members/plan';
  static const String _filesEndpoint = '/litten/note/v1/files';

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

  /// 텍스트 요약 (Claude API)
  /// POST /litten/note/v1/summary
  ///
  /// [_useMock] = true 이면 백엔드 없이 목 응답을 반환 (개발/테스트용)
  static const bool _useMock = false;

  Future<String> summarizeText({
    required String text,
    required String textLanguage,
    required String summaryLanguage,
    required int summaryRatio,
    String? fileId,
  }) async {
    debugPrint('[ApiService] summarizeText - fileId: $fileId, ratio: $summaryRatio, mock: $_useMock');

    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 1200)); // 실제 API 느낌
      return _buildMockSummary(text, summaryLanguage, summaryRatio);
    }

    try {
      final url = Uri.parse('$baseUrl$_summaryEndpoint');
      final body = jsonEncode({
        'text': text,
        'textLanguage': textLanguage,
        'summaryLanguage': summaryLanguage,
        'summaryRatio': summaryRatio,
        'fileId': fileId,
      });

      debugPrint('[ApiService] summarizeText - URL: $url');

      final response = await http
          .post(url, headers: _getHeaders(), body: body)
          .timeout(const Duration(seconds: 30));

      debugPrint('[ApiService] summarizeText - Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final success = data['success'] as bool? ?? false;

        if (success) {
          final summary = data['summary'] as String? ?? '';
          debugPrint('[ApiService] summarizeText - Success, length: ${summary.length}');
          return summary;
        } else {
          final error = data['error'] as String? ?? '요약 실패';
          debugPrint('[ApiService] summarizeText - Failed: $error');
          throw Exception(error);
        }
      } else {
        debugPrint('[ApiService] summarizeText - Failed: ${response.statusCode}');
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ApiService] summarizeText - Error: $e');
      rethrow;
    }
  }

  String _buildMockSummary(String text, String lang, int ratio) {
    final pointCount = ratio ~/ 10;
    final plain = text.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final preview = plain.length > 40 ? plain.substring(0, 40) : plain;

    final points = List.generate(pointCount, (i) => switch (i) {
      0 => '• 이 문서의 핵심 주제: "$preview..."',
      1 => '• 주요 내용이 체계적으로 정리되어 있습니다.',
      2 => '• 중요한 세부 사항이 포함되어 있습니다.',
      3 => '• 관련 맥락과 배경 정보가 서술되어 있습니다.',
      4 => '• 결론 및 요약이 문서 후반부에 위치합니다.',
      5 => '• 추가적인 참고 정보가 기술되어 있습니다.',
      6 => '• 세부 예시와 설명이 포함되어 있습니다.',
      7 => '• 관련 항목들이 상세히 나열되어 있습니다.',
      _ => '• 전반적인 내용이 명확하게 기술되어 있습니다.',
    });

    debugPrint('[ApiService] _buildMockSummary - pointCount: $pointCount, lang: $lang');
    return points.join('\n');
  }

  /// 내 구독 플랜 조회
  /// GET /litten/note/v1/members/me
  /// Response: {"result": 1, "subscriptionPlan": "free|standard|premium"}
  Future<String> getSubscriptionPlan({required String token}) async {
    debugPrint('[ApiService] getSubscriptionPlan 진입');

    try {
      final url = Uri.parse('$baseUrl$_myInfoEndpoint');
      final response = await http
          .get(url, headers: _getHeaders(token: token))
          .timeout(const Duration(seconds: 10));

      debugPrint('[ApiService] getSubscriptionPlan - status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['result'] == 1) {
          final plan = data['subscriptionPlan'] as String? ?? 'free';
          debugPrint('[ApiService] getSubscriptionPlan - plan: $plan');
          return plan;
        }
      }
      return 'free';
    } catch (e) {
      debugPrint('[ApiService] getSubscriptionPlan - 오류 (free 반환): $e');
      return 'free';
    }
  }

  /// 구독 플랜 변경
  /// PUT /litten/note/v1/members/plan
  /// {"subscriptionPlan": "premium", "planExpiredAt": "2027-05-03T00:00:00"}
  Future<bool> updateSubscriptionPlan({
    required String plan,
    required String token,
    String? planExpiredAt,
  }) async {
    debugPrint('[ApiService] updateSubscriptionPlan 진입 - plan: $plan');

    try {
      final url = Uri.parse('$baseUrl$_planEndpoint');
      final body = jsonEncode({
        'subscriptionPlan': plan,
        if (planExpiredAt != null) 'planExpiredAt': planExpiredAt,
      });

      final response = await http
          .put(url, headers: _getHeaders(token: token), body: body)
          .timeout(const Duration(seconds: 10));

      debugPrint('[ApiService] updateSubscriptionPlan - status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['result'] == 1;
      }
      return false;
    } catch (e) {
      debugPrint('[ApiService] updateSubscriptionPlan - 오류: $e');
      return false;
    }
  }

  /// 클라우드 파일 메타데이터 목록 조회
  Future<List<Map<String, dynamic>>> getCloudFiles({required String token, String? since}) async {
    debugPrint('[ApiService] getCloudFiles 진입 - since: $since');
    try {
      final uri = since != null
          ? Uri.parse('$baseUrl$_filesEndpoint?since=${Uri.encodeComponent(since)}')
          : Uri.parse('$baseUrl$_filesEndpoint');
      final response = await http.get(uri, headers: _getHeaders(token: token)).timeout(const Duration(seconds: 30));
      debugPrint('[ApiService] getCloudFiles - status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['result'] == 1) {
          return List<Map<String, dynamic>>.from(data['files'] ?? []);
        }
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getCloudFiles - 오류: $e');
      return [];
    }
  }

  /// 파일 업로드
  Future<Map<String, dynamic>?> uploadFile({
    required String token,
    required String littenId,
    required String localId,
    required String fileType,
    required String fileName,
    required String localUpdatedAt,
    required File file,
    required String contentType,
  }) async {
    debugPrint('[ApiService] uploadFile 진입 - localId: $localId, fileType: $fileType');
    try {
      final uri = Uri.parse('$baseUrl$_filesEndpoint');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(_getHeaders(token: token))
        ..fields['littenId'] = littenId
        ..fields['localId'] = localId
        ..fields['fileType'] = fileType
        ..fields['fileName'] = fileName
        ..fields['localUpdatedAt'] = localUpdatedAt
        ..files.add(await http.MultipartFile.fromPath('file', file.path, contentType: _parseMediaType(contentType)));

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      debugPrint('[ApiService] uploadFile - status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['result'] == 1) return data;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] uploadFile - 오류: $e');
      return null;
    }
  }

  /// 파일 수정 업로드
  Future<Map<String, dynamic>?> updateFile({
    required String token,
    required String cloudId,
    required String localUpdatedAt,
    required File file,
    required String contentType,
  }) async {
    debugPrint('[ApiService] updateFile 진입 - cloudId: $cloudId');
    try {
      final uri = Uri.parse('$baseUrl$_filesEndpoint/$cloudId');
      final request = http.MultipartRequest('PUT', uri)
        ..headers.addAll(_getHeaders(token: token))
        ..fields['localUpdatedAt'] = localUpdatedAt
        ..files.add(await http.MultipartFile.fromPath('file', file.path, contentType: _parseMediaType(contentType)));

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      debugPrint('[ApiService] updateFile - status: ${response.statusCode}, body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['result'] == 1) return data;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] updateFile - 오류: $e');
      return null;
    }
  }

  /// 파일 삭제
  Future<bool> deleteCloudFile({required String token, required String cloudId}) async {
    debugPrint('[ApiService] deleteCloudFile 진입 - cloudId: $cloudId');
    try {
      final uri = Uri.parse('$baseUrl$_filesEndpoint/$cloudId');
      final response = await http.delete(uri, headers: _getHeaders(token: token)).timeout(const Duration(seconds: 10));
      debugPrint('[ApiService] deleteCloudFile - status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['result'] == 1;
      }
      return false;
    } catch (e) {
      debugPrint('[ApiService] deleteCloudFile - 오류: $e');
      return false;
    }
  }

  /// 파일 다운로드
  Future<Uint8List?> downloadFile({required String token, required String cloudId}) async {
    debugPrint('[ApiService] downloadFile 진입 - cloudId: $cloudId');
    try {
      final uri = Uri.parse('$baseUrl$_filesEndpoint/$cloudId/download');
      final response = await http.get(uri, headers: _getHeaders(token: token)).timeout(const Duration(seconds: 60));
      debugPrint('[ApiService] downloadFile - status: ${response.statusCode}, size: ${response.bodyBytes.length}');
      if (response.statusCode == 200) return response.bodyBytes;
      return null;
    } catch (e) {
      debugPrint('[ApiService] downloadFile - 오류: $e');
      return null;
    }
  }

  http_parser.MediaType _parseMediaType(String contentType) {
    try {
      return http_parser.MediaType.parse(contentType);
    } catch (_) {
      return http_parser.MediaType('application', 'octet-stream');
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
