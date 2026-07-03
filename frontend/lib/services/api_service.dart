import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/youtube_channel.dart';
import '../models/summary_result.dart';

/// API 서비스
/// 백엔드 API와의 통신을 담당합니다.
class ApiService {
  // 서버 주소
  static const String baseUrl = 'http://www.litten7.com:8081';

  // API 엔드포인트
  static const String _installEndpoint = '/litten/note/v1/members/install';
  static const String _signUpEndpoint = '/litten/note/v1/members/signup';
  static const String _signupEmailCodeEndpoint =
      '/litten/note/v1/members/signup/email-code';
  static const String _signupVerifyCodeEndpoint =
      '/litten/note/v1/members/signup/verify-code';
  static const String _loginWebEndpoint = '/litten/note/v1/members/login/web';
  static const String _loginMobileEndpoint =
      '/litten/note/v1/members/login/mobile';
  static const String _passwordUrlEndpoint =
      '/litten/note/v1/members/password-url';
  static const String _passwordEndpoint = '/litten/note/v1/members/password';
  static const String _membersEndpoint = '/litten/note/v1/members';
  static const String _myInfoEndpoint = '/litten/note/v1/members/me';
  static const String _planEndpoint = '/litten/note/v1/members/plan';
  static const String _filesEndpoint = '/litten/note/v1/files';
  static const String _convertToPdfEndpoint = '/litten/note/v1/convert/to-pdf';
  static const String _youtubeChannelsEndpoint = '/litten/note/v1/youtube/channels';
  static const String _littensEndpoint = '/litten/note/v1/littens';
  static const String _schedulesEndpoint = '/litten/note/v1/schedules';
  static const String _sharesEndpoint = '/litten/note/v1/shares';
  static const String _shareGroupsEndpoint = '/litten/note/v1/share-groups';
  static const String _messagesEndpoint = '/litten/note/v1/messages';
  static const String _hiddenConvEndpoint = '/litten/note/v1/hidden-conversations';
  static const String _selfChatEndpoint = '/litten/note/v1/self-chats';

  /// HTTP 헤더 생성
  /// 비로그인(게스트) 식별용 디바이스 UUID.
  /// 앱 시작 시 AuthService.getDeviceUuid() 값으로 1회 세팅되며, 인스턴스와 무관하게
  /// 공유되도록 static으로 둔다. 로그인(JWT)이 있으면 백엔드가 JWT를 우선 처리하므로
  /// device-uuid 헤더는 비로그인(token 없음) 요청에만 붙인다.
  static String? deviceUuid;

  Map<String, String> _getHeaders({String? token}) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['auth-token'] = token;
    } else if (deviceUuid != null && deviceUuid!.isNotEmpty) {
      // 비로그인 게스트: device-uuid 헤더로 식별 (백엔드 principal = "guest:<uuid>")
      headers['device-uuid'] = deviceUuid!;
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

  /// 게스트(device-uuid) 데이터를 로그인 회원으로 이관
  /// POST /litten/note/v1/members/migrate  (JWT 헤더 필요)
  /// Body: `{"deviceUuid": "<기존 device-uuid>"}`
  /// 서버가 요약결과(member_uuid)와 유튜브 구독(`guest:uuid` → 회원 id)을 자동 이관한다.
  Future<bool> migrateGuestData({required String token, required String deviceUuid}) async {
    debugPrint('[ApiService] migrateGuestData 진입 - deviceUuid: $deviceUuid');
    try {
      final url = Uri.parse('$baseUrl/litten/note/v1/members/migrate');
      final body = jsonEncode({'deviceUuid': deviceUuid});
      final response = await http.post(url, headers: _getHeaders(token: token), body: body).timeout(const Duration(seconds: 20));
      debugPrint('[ApiService] migrateGuestData - status: ${response.statusCode}, body: ${response.body}');
      // 백엔드 응답: {result:1, migratedCount, channelMigratedCount, watchStateMigratedCount, memberUuid} — result=1이 성공
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['result'] == 1;
      }
      return false;
    } catch (e) {
      debugPrint('[ApiService] migrateGuestData - 오류: $e');
      return false;
    }
  }

  /// 로그아웃 — 현재 기기의 디바이스 슬롯(uuid1/2/3) 해제 (1계정 3장치).
  /// POST /litten/note/v1/members/logout  (JWT 헤더 필요)
  /// Body: `{"uuid": "<device-uuid>"}`
  Future<bool> logout({required String token, required String deviceUuid}) async {
    debugPrint('[ApiService] logout 진입 - deviceUuid: $deviceUuid');
    try {
      final url = Uri.parse('$baseUrl/litten/note/v1/members/logout');
      final body = jsonEncode({'uuid': deviceUuid});
      final response = await http.post(url, headers: _getHeaders(token: token), body: body)
          .timeout(const Duration(seconds: 15));
      debugPrint('[ApiService] logout - status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['result'] == 1;
      }
      return false;
    } catch (e) {
      debugPrint('[ApiService] logout - 오류: $e');
      return false;
    }
  }

  /// 등록 디바이스(uuid1/2/3 슬롯) 목록 조회 — 디바이스 관리 화면용.
  /// GET /litten/note/v1/members/devices  (JWT 헤더 필요)
  /// 각 항목: `{slot:1, uuid:"...", occupied:true}`
  Future<List<Map<String, dynamic>>> getDevices({required String token}) async {
    debugPrint('[ApiService] getDevices 진입');
    try {
      final url = Uri.parse('$baseUrl/litten/note/v1/members/devices');
      final response = await http.get(url, headers: _getHeaders(token: token))
          .timeout(const Duration(seconds: 15));
      debugPrint('[ApiService] getDevices - status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['result'] == 1) {
          final list = data['devices'] as List<dynamic>? ?? [];
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getDevices - 오류: $e');
      return [];
    }
  }

  /// 특정 디바이스 원격 해제(슬롯 비우기) — 디바이스 관리 화면용.
  /// DELETE /litten/note/v1/members/devices  (JWT 헤더 필요)
  /// Body: `{"uuid": "<해제할 device-uuid>"}`
  Future<bool> removeDevice({required String token, required String uuid}) async {
    debugPrint('[ApiService] removeDevice 진입 - uuid: $uuid');
    try {
      final url = Uri.parse('$baseUrl/litten/note/v1/members/devices');
      final body = jsonEncode({'uuid': uuid});
      final response = await http.delete(url, headers: _getHeaders(token: token), body: body)
          .timeout(const Duration(seconds: 15));
      debugPrint('[ApiService] removeDevice - status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['result'] == 1;
      }
      return false;
    } catch (e) {
      debugPrint('[ApiService] removeDevice - 오류: $e');
      return false;
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
    String? nickname, // 선택 — 입력 시 서버에서 중복 검증 후 name 컬럼에 저장
  }) async {
    debugPrint('[ApiService] signUp - email: $email, uuid: $uuid, nickname: $nickname');

    try {
      final url = Uri.parse('$baseUrl$_signUpEndpoint');
      final body = jsonEncode({
        'id': email,
        'password': password,
        'uuid': uuid,
        if (nickname != null && nickname.trim().isNotEmpty) 'name': nickname.trim(),
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

  /// 회원가입 이메일 인증번호 발송.
  /// POST /litten/note/v1/members/signup/email-code
  /// {"id": email, "lanCd": "KR"|"EN"}
  /// 반환: {result, message}. result==1 성공, 2 이미 가입, 그 외 실패.
  Future<Map<String, dynamic>> sendSignupEmailCode({
    required String email,
    String lanCd = 'KR',
  }) async {
    debugPrint('[ApiService] sendSignupEmailCode - email: $email, lanCd: $lanCd');
    try {
      final url = Uri.parse('$baseUrl$_signupEmailCodeEndpoint');
      final body = jsonEncode({'id': email, 'lanCd': lanCd});
      final response = await http
          .post(url, headers: _getHeaders(), body: body)
          .timeout(const Duration(seconds: 30));
      debugPrint(
          '[ApiService] sendSignupEmailCode - status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'result': -1, 'message': '서버 오류(${response.statusCode})'};
    } catch (e) {
      debugPrint('[ApiService] sendSignupEmailCode - 오류: $e');
      return {'result': -1, 'message': '네트워크 오류가 발생했습니다.'};
    }
  }

  /// 회원가입 이메일 인증번호 검증.
  /// POST /litten/note/v1/members/signup/verify-code
  /// {"id": email, "code": "123456"}
  /// 반환: {result, message}. result==1 성공.
  Future<Map<String, dynamic>> verifySignupEmailCode({
    required String email,
    required String code,
  }) async {
    debugPrint('[ApiService] verifySignupEmailCode - email: $email');
    try {
      final url = Uri.parse('$baseUrl$_signupVerifyCodeEndpoint');
      final body = jsonEncode({'id': email, 'code': code});
      final response = await http
          .post(url, headers: _getHeaders(), body: body)
          .timeout(const Duration(seconds: 30));
      debugPrint(
          '[ApiService] verifySignupEmailCode - status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'result': -1, 'message': '서버 오류(${response.statusCode})'};
    } catch (e) {
      debugPrint('[ApiService] verifySignupEmailCode - 오류: $e');
      return {'result': -1, 'message': '네트워크 오류가 발생했습니다.'};
    }
  }

  /// 1:1 채팅 상대 검색 — 이메일 또는 닉네임으로 가입 회원 조회.
  /// GET /note/v1/members/search?q=xxx (비인증 가능)
  /// 반환: {found:bool, id?:이메일, name?:닉네임}. 오류 시 {found:false, error:true}.
  Future<Map<String, dynamic>> searchMember(String query) async {
    final q = query.trim();
    if (q.isEmpty) return {'found': false};
    try {
      final url = Uri.parse(
          '$baseUrl$_membersEndpoint/search?q=${Uri.encodeComponent(q)}');
      final response = await http
          .get(url, headers: _getHeaders())
          .timeout(const Duration(seconds: 15));
      debugPrint('[ApiService] searchMember - status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'found': false, 'error': true};
    } catch (e) {
      debugPrint('[ApiService] searchMember - 오류: $e');
      return {'found': false, 'error': true};
    }
  }

  /// 닉네임 중복 확인. 반환: 사용 가능하면 true, 사용 중이면 false.
  /// GET /note/v1/members/nickname/check?nickname=xxx (비인증 가능)
  Future<bool> checkNicknameAvailable(String nickname) async {
    final n = nickname.trim();
    if (n.isEmpty) return false;
    try {
      final url = Uri.parse(
          '$baseUrl$_membersEndpoint/nickname/check?nickname=${Uri.encodeComponent(n)}');
      final response = await http.get(url, headers: _getHeaders())
          .timeout(const Duration(seconds: 15));
      debugPrint('[ApiService] checkNicknameAvailable - status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['available'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[ApiService] checkNicknameAvailable - 오류: $e');
      return false;
    }
  }

  /// 로그인 회원 닉네임 변경. 반환: {result, message?, name?}.
  /// PUT /note/v1/members/nickname (인증 필수)
  Future<Map<String, dynamic>> updateNickname({
    required String token,
    required String nickname,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$_membersEndpoint/nickname');
      final body = jsonEncode({'name': nickname.trim()});
      final response = await http.put(url, headers: _getHeaders(token: token), body: body)
          .timeout(const Duration(seconds: 15));
      debugPrint('[ApiService] updateNickname - status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      return {'result': -1, 'message': '서버 오류 (${response.statusCode})'};
    } catch (e) {
      debugPrint('[ApiService] updateNickname - 오류: $e');
      return {'result': -1, 'message': '$e'};
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
  /// 백엔드 요약 API 배포되어 실제 서버 호출 사용
  static const bool _useMock = false;

  Future<String> summarizeText({
    required String text,
    required String textLanguage,
    required String summaryLanguage,
    required int summaryLevel,
    String? fileId,
    String? token,
  }) async {
    debugPrint('[ApiService] summarizeText - fileId: $fileId, level: $summaryLevel, mock: $_useMock');

    if (_useMock) {
      await Future.delayed(const Duration(milliseconds: 1200)); // 실제 API 느낌
      return _buildMockSummary(text, summaryLanguage, summaryLevel);
    }

    // 신 통합 엔드포인트(/summary/process, fileType:'text')로 위임.
    // 구 엔드포인트(/summary)는 백엔드 시스템 프롬프트 미설정으로 실패함.
    try {
      final result = await processSummary(
        fileType: 'text',
        fileUuid: fileId,
        text: text,
        summaryLevel: summaryLevel,
        textLanguage: textLanguage,
        summaryLanguage: summaryLanguage,
        token: token,
      );
      // 전체 텍스트(summary) 우선 — 기존 QuizParser 호환. 없으면 순수 요약.
      final summary = result.summary.isNotEmpty ? result.summary : result.displaySummary;
      debugPrint('[ApiService] summarizeText(process) - Success, length: ${summary.length}');
      return summary;
    } catch (e) {
      debugPrint('[ApiService] summarizeText(process) - Error: $e');
      rethrow;
    }
  }

  String _buildMockSummary(String text, String lang, int level) {
    final plain = text.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final preview = plain.length > 40 ? plain.substring(0, 40) : plain;
    final clampedLevel = level.clamp(1, 5);
    const labels = ['', '한줄 요약', '간단 요약', '일반 요약', '상세 요약', '거의 전체'];
    final labelStr = labels[clampedLevel];

    final lines = switch (clampedLevel) {
      1 => ['**전체 목적**: $preview... (핵심 요약)\n**한줄 결론**: 핵심 주제와 결론 중심으로 정리됨'],
      2 => ['**전체 목적**: $preview...', '**주요 논의 내용**: 핵심 기능과 논의 포함', '**한줄 결론**: 주요 내용 중심으로 정리됨'],
      3 => ['**전체 목적**: $preview...', '**주요 논의 내용**: 실무 흐름과 논의 포함', '**핵심 기능 및 구조**: 기능별 역할 정리', '**결정 사항**: 주요 결정사항 포함', '**한줄 결론**: 실무 흐름 중심으로 정리됨'],
      4 => ['**전체 목적**: $preview...', '**주요 논의 내용**: 전체 논의 흐름 포함', '**핵심 기능 및 구조**: 구현 방향 포함', '**현재 이슈 및 고민사항**: 운영 고민 포함', '**결정 사항**: 의사결정 배경 포함', '**후속 액션**: 후속 작업 정리', '**한줄 결론**: 상세 실무 흐름 정리됨'],
      _ => ['**전체 목적**: $preview...', '**주요 논의 내용**: 전체 맥락 최대한 유지', '**핵심 기능 및 구조**: 상세 구조 포함', '**현재 이슈 및 고민사항**: 모든 이슈 포함', '**결정 사항**: 전체 의사결정 포함', '**후속 액션**: 상세 후속 작업 정리', '**한줄 결론**: 정제된 회의록 수준으로 정리됨'],
    };

    debugPrint('[ApiService] _buildMockSummary - level: $clampedLevel ($labelStr), lang: $lang');
    return lines.join('\n\n');
  }

  /// 통합 요약 처리 (요약 + 퀴즈 + 캐시/저장)
  /// POST /litten/note/v1/summary/process
  /// 유튜브: youtubeVideoId 기준 DB 캐시 확인 후 없으면 생성·저장
  Future<SummaryResult> processSummary({
    required String fileType, // 'youtube' | 'text' | 'pdf' ...
    String? youtubeVideoId,
    String? fileUuid,
    String? memberUuid,
    String? text,
    required int summaryLevel,
    required String textLanguage,
    required String summaryLanguage,
    bool forceRegenerate = false,
    String? token,
  }) async {
    debugPrint('[ApiService] processSummary - fileType: $fileType, videoId: $youtubeVideoId, level: $summaryLevel');
    final url = Uri.parse('$baseUrl/litten/note/v1/summary/process');
    final body = jsonEncode({
      'fileType': fileType,
      'youtubeVideoId': youtubeVideoId,
      'fileUuid': fileUuid,
      'memberUuid': memberUuid,
      'text': text,
      'summaryLevel': summaryLevel,
      'textLanguage': textLanguage,
      'summaryLanguage': summaryLanguage,
      'forceRegenerate': forceRegenerate,
    });
    final response = await http
        .post(url, headers: _getHeaders(token: token), body: body)
        .timeout(const Duration(seconds: 300));
    debugPrint('[ApiService] processSummary - status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final result = SummaryResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      debugPrint('[ApiService] processSummary - success: ${result.success}, quiz: ${result.totalQuizCount}');
      if (!result.success) throw Exception(result.error ?? '요약 실패');
      return result;
    }
    debugPrint('[ApiService] processSummary - 실패 body: ${response.body}');
    throw Exception('서버 오류: ${response.statusCode} ${response.body}');
  }

  /// 유튜브 영상 요약 캐시 조회 (없으면 null)
  /// GET /litten/note/v1/summary/youtube/{videoId}?summaryLevel=N
  /// summaryLevel=0 이면 저장된 가장 높은 레벨 반환
  Future<SummaryResult?> getYoutubeSummaryCache({required String videoId, int summaryLevel = 0, String? token}) async {
    try {
      final url = Uri.parse('$baseUrl/litten/note/v1/summary/youtube/$videoId?summaryLevel=$summaryLevel');
      final response = await http.get(url, headers: _getHeaders(token: token)).timeout(const Duration(seconds: 20));
      debugPrint('[ApiService] getYoutubeSummaryCache - status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final result = SummaryResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        return result.success ? result : null;
      }
      return null; // 404 = 캐시 없음
    } catch (e) {
      debugPrint('[ApiService] getYoutubeSummaryCache - 오류: $e');
      return null;
    }
  }

  /// 퀴즈 생성 (요약과 독립). 요약 없이도 youtubeVideoId+sourceText로 생성 가능.
  /// POST /litten/note/v1/quiz/process
  /// 응답은 SummaryResult 구조 재사용 (quizzes/totalQuizCount/summaryResultId).
  Future<SummaryResult> processQuiz({
    int? summaryResultId,
    String? youtubeVideoId,
    String? sourceText,
    String fileType = 'youtube',
    required int quizLevel,
    String? summaryLanguage,
    bool forceRegenerate = false,
    String? token,
  }) async {
    debugPrint('[ApiService] processQuiz - videoId: $youtubeVideoId, srId: $summaryResultId, level: $quizLevel');
    final url = Uri.parse('$baseUrl/litten/note/v1/quiz/process');
    final body = jsonEncode({
      'summaryResultId': summaryResultId,
      'youtubeVideoId': youtubeVideoId,
      'sourceText': sourceText,
      'fileType': fileType,
      'quizLevel': quizLevel,
      'summaryLanguage': summaryLanguage,
      'forceRegenerate': forceRegenerate,
    });
    final response = await http
        .post(url, headers: _getHeaders(token: token), body: body)
        .timeout(const Duration(seconds: 300));
    debugPrint('[ApiService] processQuiz - status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final result = SummaryResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      debugPrint('[ApiService] processQuiz - success: ${result.success}, quiz: ${result.totalQuizCount}');
      if (!result.success) throw Exception(result.error ?? '퀴즈 생성 실패');
      return result;
    }
    debugPrint('[ApiService] processQuiz - 실패 body: ${response.body}');
    throw Exception('서버 오류: ${response.statusCode} ${response.body}');
  }

  /// 영상 퀴즈 캐시 조회 (없으면 null)
  /// GET /litten/note/v1/quiz/youtube/{videoId}
  Future<SummaryResult?> getYoutubeQuizCache({required String videoId, String? token}) async {
    try {
      final url = Uri.parse('$baseUrl/litten/note/v1/quiz/youtube/$videoId');
      final response = await http.get(url, headers: _getHeaders(token: token)).timeout(const Duration(seconds: 20));
      debugPrint('[ApiService] getYoutubeQuizCache - status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final result = SummaryResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        return result.success ? result : null;
      }
      return null; // 404 = 캐시 없음
    } catch (e) {
      debugPrint('[ApiService] getYoutubeQuizCache - 오류: $e');
      return null;
    }
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

  /// 로그인 회원 내 정보 조회 (닉네임/이메일/플랜). JWT 기반이라 기기 무관.
  /// GET /litten/note/v1/members/me
  /// 반환: {result, memberId, name, subscriptionPlan, planExpiredAt} 또는 null
  Future<Map<String, dynamic>?> getMyInfo({required String token}) async {
    try {
      final url = Uri.parse('$baseUrl$_myInfoEndpoint');
      final response = await http
          .get(url, headers: _getHeaders(token: token))
          .timeout(const Duration(seconds: 10));
      debugPrint('[ApiService] getMyInfo - status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['result'] == 1) return data;
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] getMyInfo - 오류: $e');
      return null;
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

  /// id(가입 이메일) 기반 구독 플랜 변경 — 비인증(로그아웃 상태에서도 호출 가능).
  /// PUT /litten/note/v1/members/plan/by-id
  /// Body: {"id": "...", "subscriptionPlan": "free|standard|premium", "planExpiredAt": "..."(선택)}
  Future<bool> updateSubscriptionPlanById({
    required String id,
    required String plan,
    String? planExpiredAt,
  }) async {
    debugPrint('[ApiService] updateSubscriptionPlanById 진입 - id: $id, plan: $plan');
    try {
      final url = Uri.parse('$baseUrl$_planEndpoint/by-id');
      final body = jsonEncode({
        'id': id,
        'subscriptionPlan': plan,
        if (planExpiredAt != null) 'planExpiredAt': planExpiredAt,
      });
      final response = await http
          .put(url, headers: _getHeaders(), body: body)
          .timeout(const Duration(seconds: 10));
      debugPrint('[ApiService] updateSubscriptionPlanById - status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['result'] == 1;
      }
      return false;
    } catch (e) {
      debugPrint('[ApiService] updateSubscriptionPlanById - 오류: $e');
      return false;
    }
  }

  /// 클라우드 파일 메타데이터 목록 조회
  // files: 변경/전체 파일 메타. serverTime: 서버가 내려준 다음 증분 동기화 기준 시각(토큰).
  // serverTime을 since로 되돌려 보내면 비교가 전부 서버 시계 공간에서 일어나, 기기/서버 간
  // 타임존·시계 오차로 새 파일이 누락되던 문제를 막는다. (실패 시 serverTime=null → since 미갱신)
  Future<({List<Map<String, dynamic>> files, String? serverTime})> getCloudFiles(
      {required String token, String? since}) async {
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
          return (
            files: List<Map<String, dynamic>>.from(data['files'] ?? []),
            serverTime: data['serverTime']?.toString(),
          );
        }
      }
      return (files: <Map<String, dynamic>>[], serverTime: null);
    } catch (e) {
      debugPrint('[ApiService] getCloudFiles - 오류: $e');
      return (files: <Map<String, dynamic>>[], serverTime: null);
    }
  }

  // ── 리튼(노트 공간) 메타 동기화 (프리미엄 JWT 전용) ──────────────────────

  /// 회원의 리튼 목록 조회 (pull). 응답: {success, littens:[Litten.toJson...]}
  Future<List<Map<String, dynamic>>> getLittens({required String token}) async {
    debugPrint('[ApiService] getLittens 진입');
    try {
      final url = Uri.parse('$baseUrl$_littensEndpoint');
      final response = await http.get(url, headers: _getHeaders(token: token)).timeout(const Duration(seconds: 20));
      debugPrint('[ApiService] getLittens - status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['littens'] ?? []);
        }
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getLittens - 오류: $e');
      return [];
    }
  }

  /// 리튼 업서트 (id 기준 생성/수정). body = Litten.toJson
  Future<bool> upsertLitten({required String token, required Map<String, dynamic> littenJson}) async {
    debugPrint('[ApiService] upsertLitten 진입 - id: ${littenJson['id']}');
    try {
      final url = Uri.parse('$baseUrl$_littensEndpoint');
      final response = await http.post(url, headers: _getHeaders(token: token), body: jsonEncode(littenJson)).timeout(const Duration(seconds: 20));
      debugPrint('[ApiService] upsertLitten - status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[ApiService] upsertLitten - 오류: $e');
      return false;
    }
  }

  /// 리튼 삭제
  Future<bool> deleteLittenRemote({required String token, required String littenId}) async {
    debugPrint('[ApiService] deleteLittenRemote 진입 - littenId: $littenId');
    try {
      final url = Uri.parse('$baseUrl$_littensEndpoint/$littenId');
      final response = await http.delete(url, headers: _getHeaders(token: token)).timeout(const Duration(seconds: 20));
      debugPrint('[ApiService] deleteLittenRemote - status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[ApiService] deleteLittenRemote - 오류: $e');
      return false;
    }
  }

  // ── 캘린더 일정 동기화 (로그인 회원 전용 JWT) ─────────────────────────────

  /// 회원의 일정 목록 조회 (pull). 응답: {success, schedules:[페이로드...]}
  Future<List<Map<String, dynamic>>> getSchedules({required String token}) async {
    debugPrint('[ApiService] getSchedules 진입');
    try {
      final url = Uri.parse('$baseUrl$_schedulesEndpoint');
      final response = await http.get(url, headers: _getHeaders(token: token)).timeout(const Duration(seconds: 20));
      debugPrint('[ApiService] getSchedules - status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['schedules'] ?? []);
        }
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getSchedules - 오류: $e');
      return [];
    }
  }

  /// 일정 업서트 (littenId 기준 생성/수정).
  /// body = { littenId, title, updatedAt, notificationCount, schedule:{LittenSchedule.toJson} }
  Future<bool> upsertSchedule({required String token, required Map<String, dynamic> scheduleJson}) async {
    debugPrint('[ApiService] upsertSchedule 진입 - littenId: ${scheduleJson['littenId']}');
    try {
      final url = Uri.parse('$baseUrl$_schedulesEndpoint');
      final response = await http.post(url, headers: _getHeaders(token: token), body: jsonEncode(scheduleJson)).timeout(const Duration(seconds: 20));
      debugPrint('[ApiService] upsertSchedule - status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[ApiService] upsertSchedule - 오류: $e');
      return false;
    }
  }

  /// 일정 삭제 (littenId 기준)
  Future<bool> deleteSchedule({required String token, required String littenId}) async {
    debugPrint('[ApiService] deleteSchedule 진입 - littenId: $littenId');
    try {
      final url = Uri.parse('$baseUrl$_schedulesEndpoint/$littenId');
      final response = await http.delete(url, headers: _getHeaders(token: token)).timeout(const Duration(seconds: 20));
      debugPrint('[ApiService] deleteSchedule - status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[ApiService] deleteSchedule - 오류: $e');
      return false;
    }
  }

  // ───────────────────────── 사용자 간 공유 / 그룹 ─────────────────────────

  /// 파일을 사용자(개인) 또는 그룹에 공유. 본문을 multipart로 업로드.
  /// 반환: {success, shareId?, recipientCount?, message?}
  Future<Map<String, dynamic>> shareFile({
    required String token,
    required String targetType, // 'user' | 'group'
    String? recipientKey, // user일 때 이메일/이름
    int? groupId, // group일 때
    String? littenTitle,
    required String fileType,
    required String fileName,
    String? contentType,
    String? message,
    required File file,
  }) async {
    debugPrint('[ApiService] shareFile 진입 - target: $targetType, file: $fileName');
    try {
      final uri = Uri.parse('$baseUrl$_sharesEndpoint');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(_getHeaders(token: token))
        ..fields['targetType'] = targetType
        ..fields['fileType'] = fileType
        ..fields['fileName'] = fileName;
      if (recipientKey != null) request.fields['recipientKey'] = recipientKey;
      if (groupId != null) request.fields['groupId'] = '$groupId';
      if (littenTitle != null) request.fields['littenTitle'] = littenTitle;
      if (contentType != null) request.fields['contentType'] = contentType;
      if (message != null && message.isNotEmpty) request.fields['message'] = message;
      request.files.add(await http.MultipartFile.fromPath('file', file.path,
          contentType: _parseMediaType(contentType ?? 'application/octet-stream')));

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      debugPrint('[ApiService] shareFile - status: ${response.statusCode}, body: ${response.body}');
      if (response.body.isNotEmpty) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      return {'success': false, 'message': '응답이 없습니다'};
    } catch (e) {
      debugPrint('[ApiService] shareFile - 오류: $e');
      return {'success': false, 'message': '$e'};
    }
  }

  /// 수신자 조회(보내기 전 확인). 반환: {found, name?}
  Future<Map<String, dynamic>?> lookupRecipient({required String token, required String key}) async {
    try {
      final uri = Uri.parse('$baseUrl$_sharesEndpoint/lookup?key=${Uri.encodeComponent(key)}');
      final response = await http.get(uri, headers: _getHeaders(token: token))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] lookupRecipient - 오류: $e');
      return null;
    }
  }

  /// 받은 공유 목록. **실패 시 null**(빈 목록 []과 구분) — 취소 감지 시 오삭제 방지용.
  Future<List<Map<String, dynamic>>?> getSharesReceived({required String token}) async {
    return _getShareList('$baseUrl$_sharesEndpoint/received', token);
  }

  /// 보낸 공유 목록. **실패 시 null**(빈 목록 []과 구분).
  Future<List<Map<String, dynamic>>?> getSharesSent({required String token}) async {
    return _getShareList('$baseUrl$_sharesEndpoint/sent', token);
  }

  // ── 채팅 메시지 ──
  /// 메시지 전송. 반환: {success, messageId?, recipientCount?, message?}
  Future<Map<String, dynamic>> sendMessage({
    required String token,
    required String targetType, // 'user' | 'group'
    String? recipientKey,
    int? groupId,
    required String content,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$_messagesEndpoint');
      final body = jsonEncode({
        'targetType': targetType,
        if (recipientKey != null) 'recipientKey': recipientKey,
        if (groupId != null) 'groupId': groupId,
        'content': content,
      });
      final res = await http.post(url, headers: _getHeaders(token: token), body: body)
          .timeout(const Duration(seconds: 20));
      debugPrint('[ApiService] sendMessage - status: ${res.statusCode}, body: ${res.body}');
      if (res.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(res.body));
      return {'success': false, 'message': '서버 오류 (${res.statusCode})'};
    } catch (e) {
      debugPrint('[ApiService] sendMessage - 오류: $e');
      return {'success': false, 'message': '$e'};
    }
  }

  /// 받은 메시지 목록. 실패 시 null(빈 목록 []과 구분).
  Future<List<Map<String, dynamic>>?> getMessagesReceived({required String token}) =>
      _getMessageList('$baseUrl$_messagesEndpoint/received', token);

  /// 보낸 메시지 목록. 실패 시 null.
  Future<List<Map<String, dynamic>>?> getMessagesSent({required String token}) =>
      _getMessageList('$baseUrl$_messagesEndpoint/sent', token);

  Future<List<Map<String, dynamic>>?> _getMessageList(String url, String token) async {
    try {
      final res = await http.get(Uri.parse(url), headers: _getHeaders(token: token))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['messages'] ?? []);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] _getMessageList - 오류: $e');
      return null;
    }
  }

  // ── 대화 숨김('방 나가기') 다기기 동기화 ──
  /// 내 숨김 대화 목록. 실패 시 null. 반환 각 항목: {convKey, hiddenAt}
  Future<List<Map<String, dynamic>>?> getHiddenConversations({required String token}) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl$_hiddenConvEndpoint'),
              headers: _getHeaders(token: token))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['hidden'] ?? []);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] getHiddenConversations - 오류: $e');
      return null;
    }
  }

  /// 대화 숨김 등록(방 나가기). 성공 여부 반환.
  Future<bool> hideConversation({required String token, required String convKey}) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl$_hiddenConvEndpoint'),
              headers: _getHeaders(token: token), body: jsonEncode({'convKey': convKey}))
          .timeout(const Duration(seconds: 20));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] hideConversation - 오류: $e');
      return false;
    }
  }

  // ── 나와의 대화(셀프 채팅) 다기기 동기화 ──
  /// 내 셀프챗 방+항목 조회. 실패 시 null. 각 방: {id, clientId, name, items:[...]}
  Future<List<Map<String, dynamic>>?> getSelfChats({required String token}) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl$_selfChatEndpoint'),
              headers: _getHeaders(token: token))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['selfChats'] ?? []);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] getSelfChats - 오류: $e');
      return null;
    }
  }

  /// 셀프챗 방 생성/업서트. 반환: {id, clientId, name} or null.
  Future<Map<String, dynamic>?> createSelfChat(
      {required String token, required String name, required String clientId}) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl$_selfChatEndpoint'),
              headers: _getHeaders(token: token),
              body: jsonEncode({'name': name, 'clientId': clientId}))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) return Map<String, dynamic>.from(data['selfChat'] ?? {});
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] createSelfChat - 오류: $e');
      return null;
    }
  }

  Future<bool> deleteSelfChat({required String token, required int serverId}) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl$_selfChatEndpoint/$serverId'),
              headers: _getHeaders(token: token))
          .timeout(const Duration(seconds: 20));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] deleteSelfChat - 오류: $e');
      return false;
    }
  }

  /// 셀프챗 텍스트 추가. 반환: {itemId, ...} or null.
  Future<Map<String, dynamic>?> addSelfChatMessage(
      {required String token, required int serverId, required String content}) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl$_selfChatEndpoint/$serverId/messages'),
              headers: _getHeaders(token: token), body: jsonEncode({'content': content}))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) return Map<String, dynamic>.from(data['item'] ?? {});
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] addSelfChatMessage - 오류: $e');
      return null;
    }
  }

  /// 셀프챗 파일 추가(multipart). 반환: {itemId, ...} or null.
  Future<Map<String, dynamic>?> addSelfChatFile({
    required String token,
    required int serverId,
    required String fileType,
    required String fileName,
    String? contentType,
    required File file,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$_selfChatEndpoint/$serverId/files');
      final req = http.MultipartRequest('POST', uri)
        ..headers.addAll(_getHeaders(token: token))
        ..fields['fileType'] = fileType
        ..fields['fileName'] = fileName;
      if (contentType != null) req.fields['contentType'] = contentType;
      req.files.add(await http.MultipartFile.fromPath('file', file.path,
          contentType: _parseMediaType(contentType ?? 'application/octet-stream')));
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) return Map<String, dynamic>.from(data['item'] ?? {});
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] addSelfChatFile - 오류: $e');
      return null;
    }
  }

  /// 셀프챗 파일 다운로드. 반환: bytes or null.
  Future<List<int>?> downloadSelfChatItem({required String token, required int itemId}) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl$_selfChatEndpoint/items/$itemId/download'),
              headers: _getHeaders(token: token))
          .timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) return res.bodyBytes;
      return null;
    } catch (e) {
      debugPrint('[ApiService] downloadSelfChatItem - 오류: $e');
      return null;
    }
  }

  /// 공유 목록 조회. 성공이면 목록(빈 목록 가능), **네트워크/서버 실패면 null**.
  Future<List<Map<String, dynamic>>?> _getShareList(String url, String token) async {
    try {
      final response = await http.get(Uri.parse(url), headers: _getHeaders(token: token))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['shares'] ?? []);
        }
      }
      return null; // 비정상 응답 → 실패로 간주
    } catch (e) {
      debugPrint('[ApiService] _getShareList - 오류: $e');
      return null; // 네트워크 실패
    }
  }

  /// 수락. 반환: {success, shareId?, status?} (shareId로 다운로드)
  Future<Map<String, dynamic>?> acceptShare({required String token, required int deliveryId}) async {
    return _postShareAction('$baseUrl$_sharesEndpoint/deliveries/$deliveryId/accept', token);
  }

  Future<bool> rejectShare({required String token, required int deliveryId}) async {
    final r = await _postShareAction('$baseUrl$_sharesEndpoint/deliveries/$deliveryId/reject', token);
    return r?['success'] == true;
  }

  /// 발신자 공유 취소(회수)
  Future<bool> cancelShare({required String token, required int shareId}) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl$_sharesEndpoint/$shareId'),
          headers: _getHeaders(token: token)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as Map<String, dynamic>)['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[ApiService] cancelShare - 오류: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _postShareAction(String url, String token) async {
    try {
      final response = await http.post(Uri.parse(url), headers: _getHeaders(token: token))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] _postShareAction - 오류: $e');
      return null;
    }
  }

  /// 수락한 공유 본문 다운로드
  Future<Uint8List?> downloadShare({required String token, required int shareId}) async {
    try {
      final uri = Uri.parse('$baseUrl$_sharesEndpoint/$shareId/download');
      final response = await http.get(uri, headers: _getHeaders(token: token))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) return response.bodyBytes;
      return null;
    } catch (e) {
      debugPrint('[ApiService] downloadShare - 오류: $e');
      return null;
    }
  }

  // ── 그룹 ──
  Future<Map<String, dynamic>?> createGroup({
    required String token,
    required String name,
    String? password,
    List<String>? members,
  }) async {
    try {
      final body = <String, dynamic>{'name': name};
      if (password != null && password.isNotEmpty) body['password'] = password;
      if (members != null && members.isNotEmpty) body['members'] = members;
      final response = await http.post(Uri.parse('$baseUrl$_shareGroupsEndpoint'),
          headers: _getHeaders(token: token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) return Map<String, dynamic>.from(data['group']);
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] createGroup - 오류: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getGroups({required String token}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl$_shareGroupsEndpoint'),
          headers: _getHeaders(token: token)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) return List<Map<String, dynamic>>.from(data['groups'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getGroups - 오류: $e');
      return [];
    }
  }

  Future<bool> deleteGroup({required String token, required int groupId}) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl$_shareGroupsEndpoint/$groupId'),
          headers: _getHeaders(token: token)).timeout(const Duration(seconds: 20));
      return response.statusCode == 200 &&
          (jsonDecode(response.body) as Map<String, dynamic>)['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] deleteGroup - 오류: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getGroupMembers({required String token, required int groupId}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl$_shareGroupsEndpoint/$groupId/members'),
          headers: _getHeaders(token: token)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) return List<Map<String, dynamic>>.from(data['members'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] getGroupMembers - 오류: $e');
      return [];
    }
  }

  /// 멤버 추가. 반환: {success, member?, message?}
  Future<Map<String, dynamic>> addGroupMember({required String token, required int groupId, required String key}) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl$_shareGroupsEndpoint/$groupId/members'),
          headers: _getHeaders(token: token), body: jsonEncode({'key': key}))
          .timeout(const Duration(seconds: 20));
      if (response.body.isNotEmpty) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      return {'success': false, 'message': '응답이 없습니다'};
    } catch (e) {
      debugPrint('[ApiService] addGroupMember - 오류: $e');
      return {'success': false, 'message': '$e'};
    }
  }

  Future<bool> removeGroupMember({required String token, required int groupId, required String memberId}) async {
    try {
      final uri = Uri.parse('$baseUrl$_shareGroupsEndpoint/$groupId/members?memberId=${Uri.encodeComponent(memberId)}');
      final response = await http.delete(uri, headers: _getHeaders(token: token))
          .timeout(const Duration(seconds: 20));
      return response.statusCode == 200 &&
          (jsonDecode(response.body) as Map<String, dynamic>)['success'] == true;
    } catch (e) {
      debugPrint('[ApiService] removeGroupMember - 오류: $e');
      return false;
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
    String? fileName, // 제목 변경 전파용(텍스트). 서버 fileName/저장경로 갱신.
  }) async {
    debugPrint('[ApiService] updateFile 진입 - cloudId: $cloudId, fileName: $fileName');
    try {
      final uri = Uri.parse('$baseUrl$_filesEndpoint/$cloudId');
      final request = http.MultipartRequest('PUT', uri)
        ..headers.addAll(_getHeaders(token: token))
        ..fields['localUpdatedAt'] = localUpdatedAt
        ..files.add(await http.MultipartFile.fromPath('file', file.path, contentType: _parseMediaType(contentType)));
      if (fileName != null) request.fields['fileName'] = fileName;

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

  /// 파일을 PDF로 변환 (LibreOffice headless)
  /// POST /litten/note/v1/convert/to-pdf
  /// Returns: PDF bytes
  Future<Uint8List> convertToPdf({
    required String filePath,
    required String fileName,
    String? token,
  }) async {
    debugPrint('[ApiService] convertToPdf 진입 - filePath: $filePath, fileName: $fileName');

    try {
      final url = Uri.parse('$baseUrl$_convertToPdfEndpoint');
      final request = http.MultipartRequest('POST', url);

      if (token != null) {
        request.headers['auth-token'] = token;
      }

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: fileName,
      ));

      debugPrint('[ApiService] convertToPdf - URL: $url');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 300));
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('[ApiService] convertToPdf - Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('[ApiService] convertToPdf - 성공, size: ${response.bodyBytes.length} bytes');
        return response.bodyBytes;
      } else {
        debugPrint('[ApiService] convertToPdf - 실패: ${response.statusCode}, ${response.body}');
        throw Exception('PDF 변환 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[ApiService] convertToPdf - Error: $e');
      rethrow;
    }
  }

  // ── 유튜브 채널 구독 ───────────────────────────────────────────────────────

  static const String _youtubeChannelsCacheKey = 'youtube_channels_cache';

  /// 구독 중인 유튜브 채널 목록 조회 (페이지네이션 + 실패 시 캐시 반환)
  Future<List<YoutubeChannel>> getYoutubeChannels({
    required String token,
    int page = 0,
    int size = 5,
  }) async {
    debugPrint('[ApiService] getYoutubeChannels 진입 - page: $page, size: $size');
    try {
      final url = Uri.parse('$baseUrl$_youtubeChannelsEndpoint?page=$page&size=$size');
      final response = await http.get(url, headers: _getHeaders(token: token)).timeout(const Duration(seconds: 15));
      debugPrint('[ApiService] getYoutubeChannels - status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final list = data['channels'] as List<dynamic>? ?? [];
          final channels = list.map((e) => YoutubeChannel.fromJson(e as Map<String, dynamic>)).toList();
          // 첫 페이지 성공 시 캐시 저장
          if (page == 0) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_youtubeChannelsCacheKey, response.body);
            debugPrint('[ApiService] getYoutubeChannels - 캐시 저장: ${channels.length}개');
          }
          return channels;
        }
      }
      return page == 0 ? _loadYoutubeChannelsFromCache() : [];
    } catch (e) {
      debugPrint('[ApiService] getYoutubeChannels - 오류: $e → ${page == 0 ? "캐시 사용" : "빈 목록"}');
      return page == 0 ? _loadYoutubeChannelsFromCache() : [];
    }
  }

  Future<List<YoutubeChannel>> _loadYoutubeChannelsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_youtubeChannelsCacheKey);
      if (cached == null) return [];
      final data = jsonDecode(cached) as Map<String, dynamic>;
      final list = data['channels'] as List<dynamic>? ?? [];
      debugPrint('[ApiService] getYoutubeChannels - 캐시에서 ${list.length}개 로드');
      return list.map((e) => YoutubeChannel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[ApiService] getYoutubeChannels - 캐시 로드 실패: $e');
      return [];
    }
  }

  /// 유튜브 채널 구독 등록
  Future<YoutubeChannel?> subscribeYoutubeChannel({
    String? token,
    required String channelId,
    required String channelName,
    String channelThumbnail = '',
    bool autoTitle = true,
    bool autoMemo = false,
    bool autoSummary = false,
    String? summaryType,
    bool autoQuiz = false,
    String? quizType,
    int? quizCustomCount,
  }) async {
    debugPrint('[ApiService] subscribeYoutubeChannel 진입 - channelId: $channelId, autoSummary: $autoSummary($summaryType), autoQuiz: $autoQuiz($quizType${quizType == 'CUSTOM' ? '=$quizCustomCount' : ''})');
    try {
      final url = Uri.parse('$baseUrl$_youtubeChannelsEndpoint');
      final body = jsonEncode({
        'channelId': channelId,
        'channelName': channelName,
        'channelThumbnail': channelThumbnail,
        'autoTitle': autoTitle,
        'autoMemo': autoMemo,
        'autoSummary': autoSummary,
        if (autoSummary && summaryType != null) 'summaryType': summaryType,
        'autoQuiz': autoQuiz,
        if (autoQuiz && quizType != null) 'quizType': quizType,
        if (autoQuiz && quizType == 'CUSTOM' && quizCustomCount != null)
          'quizCustomCount': quizCustomCount,
      });
      final response = await http.post(url, headers: _getHeaders(token: token), body: body).timeout(const Duration(seconds: 15));
      debugPrint('[ApiService] subscribeYoutubeChannel - status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['channel'] != null) {
          return YoutubeChannel.fromJson(data['channel'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] subscribeYoutubeChannel - 오류: $e');
      return null;
    }
  }

  /// 유튜브 채널 자동화 설정 업데이트
  ///
  /// `null` 인 boolean/string은 PATCH body에서 제외되어 백엔드에서 무시된다.
  /// `summaryType`, `quizType`, `quizCustomCount`는 명시적으로 null 전달을 원할 때 `clear*` 플래그 사용.
  Future<bool> updateYoutubeChannelSettings({
    required String token,
    required int channelPk,
    bool? autoTitle,
    bool? autoMemo,
    bool? autoSummary,
    String? summaryType,
    bool clearSummaryType = false,
    bool? autoQuiz,
    String? quizType,
    bool clearQuizType = false,
    int? quizCustomCount,
    bool clearQuizCustomCount = false,
  }) async {
    debugPrint('[ApiService] updateYoutubeChannelSettings 진입 - channelPk: $channelPk, autoSummary: $autoSummary($summaryType), autoQuiz: $autoQuiz($quizType${quizType == 'CUSTOM' ? '=$quizCustomCount' : ''})');
    try {
      final url = Uri.parse('$baseUrl$_youtubeChannelsEndpoint/$channelPk');
      final body = <String, dynamic>{};
      if (autoTitle != null)   body['autoTitle']   = autoTitle;
      if (autoMemo != null)    body['autoMemo']    = autoMemo;
      if (autoSummary != null) body['autoSummary'] = autoSummary;
      if (summaryType != null) {
        body['summaryType'] = summaryType;
      } else if (clearSummaryType) {
        body['summaryType'] = null;
      }
      if (autoQuiz != null) body['autoQuiz'] = autoQuiz;
      if (quizType != null) {
        body['quizType'] = quizType;
      } else if (clearQuizType) {
        body['quizType'] = null;
      }
      if (quizCustomCount != null) {
        body['quizCustomCount'] = quizCustomCount;
      } else if (clearQuizCustomCount) {
        body['quizCustomCount'] = null;
      }
      final response = await http.patch(url, headers: _getHeaders(token: token), body: jsonEncode(body)).timeout(const Duration(seconds: 15));
      debugPrint('[ApiService] updateYoutubeChannelSettings - status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] updateYoutubeChannelSettings - 오류: $e');
      return false;
    }
  }

  /// 유튜브 채널 구독 해제
  Future<bool> unsubscribeYoutubeChannel({String? token, required int channelPk}) async {
    debugPrint('[ApiService] unsubscribeYoutubeChannel 진입 - channelPk: $channelPk');
    try {
      final url = Uri.parse('$baseUrl$_youtubeChannelsEndpoint/$channelPk');
      final response = await http.delete(url, headers: _getHeaders(token: token)).timeout(const Duration(seconds: 15));
      debugPrint('[ApiService] unsubscribeYoutubeChannel - status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] unsubscribeYoutubeChannel - 오류: $e');
      return false;
    }
  }

  /// 채널 ID로 유튜브 채널 정보 조회 (구독 전 검증)
  Future<Map<String, String>?> getYoutubeChannelInfo({required String token, required String channelId}) async {
    debugPrint('[ApiService] getYoutubeChannelInfo 진입 - channelId: $channelId');
    try {
      final url = Uri.parse('$baseUrl$_youtubeChannelsEndpoint/info?channelId=${Uri.encodeComponent(channelId)}');
      final response = await http.get(url, headers: _getHeaders(token: token)).timeout(const Duration(seconds: 15));
      debugPrint('[ApiService] getYoutubeChannelInfo - status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['channel'] != null) {
          final ch = data['channel'] as Map<String, dynamic>;
          return {
            'channelId': ch['channelId']?.toString() ?? '',
            'channelName': ch['channelName']?.toString() ?? '',
            'channelThumbnail': ch['channelThumbnail']?.toString() ?? '',
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] getYoutubeChannelInfo - 오류: $e');
      return null;
    }
  }

  /// 채널의 영상 목록 조회 (제목만, 페이징)
  Future<YoutubeVideosResult> getYoutubeVideos({
    String? token,
    required String channelId,
    int page = 0,
    int size = 3,
  }) async {
    debugPrint('[ApiService] getYoutubeVideos 진입 - channelId: $channelId, page: $page, size: $size');
    try {
      final url = Uri.parse('$baseUrl$_youtubeChannelsEndpoint/$channelId/videos?page=$page&size=$size');
      final response = await http.get(url, headers: _getHeaders(token: token)).timeout(const Duration(seconds: 15));
      debugPrint('[ApiService] getYoutubeVideos - status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final list = data['videos'] as List<dynamic>? ?? [];
          final videos = list.map((e) => YoutubeVideo.fromJson(e as Map<String, dynamic>)).toList();
          final totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
          return YoutubeVideosResult(videos: videos, totalPages: totalPages);
        }
      }
      return const YoutubeVideosResult(videos: [], totalPages: 0);
    } catch (e) {
      debugPrint('[ApiService] getYoutubeVideos - 오류: $e');
      return const YoutubeVideosResult(videos: [], totalPages: 0);
    }
  }

  /// 영상 상세 조회 (자막/요약 포함)
  Future<YoutubeVideo?> getYoutubeVideoDetail({required String token, required int videoId}) async {
    debugPrint('[ApiService] getYoutubeVideoDetail 진입 - videoId: $videoId');
    try {
      final url = Uri.parse('$baseUrl/litten/note/v1/youtube/videos/$videoId');
      final response = await http.get(url, headers: _getHeaders(token: token)).timeout(const Duration(seconds: 15));
      debugPrint('[ApiService] getYoutubeVideoDetail - status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return YoutubeVideo.fromJson(data['video'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] getYoutubeVideoDetail - 오류: $e');
      return null;
    }
  }

  /// 클라이언트에서 수집한 자막을 서버에 저장
  Future<bool> saveYoutubeTranscript({
    required String token,
    required String videoId,
    required String transcript,
  }) async {
    debugPrint('[ApiService] saveYoutubeTranscript 진입 - videoId: $videoId, length: ${transcript.length}');
    try {
      final url = Uri.parse('$baseUrl/litten/note/v1/youtube/videos/$videoId/transcript');
      final response = await http.post(
        url,
        headers: _getHeaders(token: token),
        body: jsonEncode({'transcript': transcript}),
      ).timeout(const Duration(seconds: 15));
      debugPrint('[ApiService] saveYoutubeTranscript - status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] saveYoutubeTranscript - 오류: $e');
      return false;
    }
  }

  /// 백엔드 yt-dlp로 YouTube 자막 추출 (신규)
  /// downsub.com과 동일한 방식 — yt-dlp가 PoToken 자체 처리
  Future<String?> extractYoutubeTranscriptViaYtDlp({
    required String token,
    required String videoId,
  }) async {
    debugPrint('[ApiService] extractYoutubeTranscriptViaYtDlp 진입 - videoId: $videoId');
    try {
      final url = Uri.parse('$baseUrl/litten/note/v1/youtube/videos/$videoId/transcript-ytdlp');
      final response = await http.post(
        url,
        headers: _getHeaders(token: token),
      ).timeout(const Duration(seconds: 90)); // yt-dlp는 시간이 더 필요
      debugPrint('[ApiService] extractYoutubeTranscriptViaYtDlp - status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['transcript'] != null) {
          final transcript = data['transcript'] as String;
          debugPrint('[ApiService] extractYoutubeTranscriptViaYtDlp - 성공, length: ${transcript.length}');
          return transcript;
        }
      }
      debugPrint('[ApiService] extractYoutubeTranscriptViaYtDlp - 실패: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[ApiService] extractYoutubeTranscriptViaYtDlp - 오류: $e');
      return null;
    }
  }
}
