import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'api_service.dart';

/// 인증 상태를 나타내는 열거형
enum AuthStatus {
  authenticated,    // 인증됨
  unauthenticated, // 인증되지 않음
  loading,         // 로딩 중
}

/// 구독 플랜 열거형
enum SubscriptionPlan { free, standard, premium }

/// 사용자 모델
class User {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final SubscriptionPlan subscriptionPlan;

  User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.createdAt,
    this.subscriptionPlan = SubscriptionPlan.free,
  });

  User copyWith({SubscriptionPlan? subscriptionPlan, String? displayName}) {
    return User(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl,
      createdAt: createdAt,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
    );
  }

  bool get isPremium => subscriptionPlan == SubscriptionPlan.premium;
  bool get isStandardOrAbove => subscriptionPlan == SubscriptionPlan.standard || subscriptionPlan == SubscriptionPlan.premium;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
      'subscriptionPlan': subscriptionPlan.name,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      subscriptionPlan: SubscriptionPlan.values.firstWhere(
        (p) => p.name == (json['subscriptionPlan'] as String? ?? 'free'),
        orElse: () => SubscriptionPlan.free,
      ),
    );
  }
}

/// 인증 서비스 인터페이스
///
/// 2차 개발 시 백엔드 연동을 위한 기본 구조
/// 현재는 인터페이스만 제공하며, 실제 구현은 2차 개발에서 진행
abstract class AuthService extends ChangeNotifier {
  /// 현재 인증 상태
  AuthStatus get authStatus;

  /// 현재 로그인한 사용자 (null이면 미로그인)
  User? get currentUser;

  /// 이메일/비밀번호 로그인
  ///
  /// [email] 사용자 이메일
  /// [password] 사용자 비밀번호
  ///
  /// Returns: 성공 시 User 객체, 실패 시 예외 발생
  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// 이메일/비밀번호 회원가입
  ///
  /// [email] 사용자 이메일
  /// [password] 사용자 비밀번호
  /// [displayName] 표시 이름 (선택사항)
  ///
  /// Returns: 성공 시 User 객체, 실패 시 예외 발생
  Future<User> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  });

  /// Google 로그인
  ///
  /// Returns: 성공 시 User 객체, 실패 시 예외 발생
  Future<User> signInWithGoogle();

  /// Apple 로그인
  ///
  /// Returns: 성공 시 User 객체, 실패 시 예외 발생
  Future<User> signInWithApple();

  /// 로그아웃
  Future<void> signOut();

  /// 비밀번호 재설정 이메일 전송
  ///
  /// [email] 비밀번호를 재설정할 이메일
  Future<void> sendPasswordResetEmail(String email);

  /// 비밀번호 변경
  ///
  /// [currentPassword] 현재 비밀번호
  /// [newPassword] 새 비밀번호
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// 사용자 정보 업데이트
  ///
  /// [displayName] 새로운 표시 이름
  /// [photoUrl] 새로운 프로필 사진 URL
  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
  });

  /// 계정 삭제
  Future<void> deleteAccount();

  /// 인증 상태 스트림
  ///
  /// 인증 상태가 변경될 때마다 새로운 값을 방출
  Stream<User?> get authStateChanges;
}

/// AuthService의 기본 구현 (개발 환경용)
///
/// 실제 백엔드 연동 전까지 사용할 더미 구현
class AuthServiceImpl extends AuthService {
  AuthStatus _authStatus = AuthStatus.unauthenticated;
  User? _currentUser;
  String? _token;
  String? _deviceUuid;
  final ApiService _apiService = ApiService();
  final Uuid _uuid = const Uuid();

  // 구글 로그인 서버 클라이언트 ID(웹 애플리케이션 OAuth 클라이언트) —
  // idToken의 aud가 이 값이 되도록 하여 서버(SOCIAL_GOOGLE_CLIENT_IDS)와 검증 기준을 일치시킴.
  // Android는 이 serverClientId가 있어야 idToken을 발급받음.
  static const String _googleServerClientId =
      '193100413025-piut8r6uuvpi9acpfknkce688veq7e8b.apps.googleusercontent.com';

  // SharedPreferences 키
  static const String _keyToken = 'auth_token';
  static const String _keyEmail = 'user_email';
  static const String _keyUserId = 'user_id';
  static const String _keyTokenExpiredDate = 'token_expired_date';
  static const String _keyDeviceUuid = 'device_uuid';
  static const String _keyRegisteredEmail = 'registered_email'; // 최초 회원가입한 이메일
  static const String _keySubscriptionPlan = 'subscription_type';

  @override
  AuthStatus get authStatus => _authStatus;

  @override
  User? get currentUser => _currentUser;

  /// 최초 회원가입한 이메일 가져오기
  Future<String?> getRegisteredEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRegisteredEmail);
  }

  /// 디바이스 UUID 가져오기 (public 메소드)
  Future<String> getDeviceUuid() async {
    return await _getOrCreateDeviceUuid();
  }

  /// 디바이스 UUID 가져오기 또는 생성
  Future<String> _getOrCreateDeviceUuid() async {
    final prefs = await SharedPreferences.getInstance();
    String? uuid = prefs.getString(_keyDeviceUuid);

    if (uuid == null) {
      uuid = _uuid.v4();
      await prefs.setString(_keyDeviceUuid, uuid);
      debugPrint('🔐 AuthService: 새로운 UUID 생성 - $uuid');
    } else {
      debugPrint('🔐 AuthService: 기존 UUID 사용 - $uuid');
    }

    _deviceUuid = uuid;
    ApiService.deviceUuid = uuid; // 비로그인 게스트 식별 헤더용으로 ApiService에 공유
    return uuid;
  }

  /// UUID를 서버에 등록
  /// 앱 설치 후 처음 실행 시 또는 언어 선택 시 호출
  Future<void> registerDeviceUuid() async {
    debugPrint('🔐 AuthService: UUID 등록 시작');

    try {
      final uuid = await _getOrCreateDeviceUuid();
      await _apiService.registerUuid(uuid: uuid);
      debugPrint('🔐 AuthService: UUID 등록 성공 - $uuid');
    } catch (e) {
      debugPrint('🔐 AuthService: UUID 등록 실패 - $e');
      // UUID 등록 실패는 앱 사용을 막지 않음
    }
  }

  /// 로그인 상태 확인
  Future<void> checkAuthStatus() async {
    debugPrint('🔐 AuthService: 로그인 상태 확인');

    // API 응답 기반 훅 등록(1회): 서버가 재발급한 토큰 저장(A) / 401(만료) 시 자동 로그아웃(B).
    ApiService.onTokenRefreshed = (token) => saveRefreshedToken(token);
    ApiService.onUnauthorized = () => enforceTokenValidity();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_keyToken);
      final email = prefs.getString(_keyEmail);
      final userId = prefs.getString(_keyUserId);

      // 디바이스 UUID 확인 또는 생성
      await _getOrCreateDeviceUuid();

      // 저장된 토큰이 이미 만료됐으면 로그인 상태로 시작하지 않는다(로그아웃 상태 → 재로그인 유도).
      if (token != null && _isJwtExpired(token)) {
        debugPrint('🔐 AuthService: 저장된 토큰 만료 → 로그아웃 상태로 시작');
        await _clearAuthData();
        _token = null;
        _currentUser = null;
        _authStatus = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      if (token != null && email != null && userId != null) {
        _token = token;
        // TODO: 개발 중 — 구독 플랜 강제 프리미엄 (출시 전 제거)
        const planStr = 'premium';
        final plan = SubscriptionPlan.premium;
        _currentUser = User(
          id: userId,
          email: email,
          createdAt: DateTime.now(),
          subscriptionPlan: plan,
        );
        _authStatus = AuthStatus.authenticated;
        debugPrint('🔐 AuthService: 로그인 상태 - $email, plan: $planStr');
      } else {
        _authStatus = AuthStatus.unauthenticated;
        debugPrint('🔐 AuthService: 비로그인 상태');
      }
      notifyListeners();
    } catch (e) {
      debugPrint('🔐 AuthService: 로그인 상태 확인 오류 - $e');
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  /// 로그인 정보 저장
  Future<void> _saveAuthData({
    required String token,
    required String email,
    required String userId,
    int? tokenExpiredDate,
  }) async {
    debugPrint('🔐 AuthService: 로그인 정보 저장 - $email');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyUserId, userId);

    if (tokenExpiredDate != null) {
      await prefs.setInt(_keyTokenExpiredDate, tokenExpiredDate);
      debugPrint('🔐 AuthService: 토큰 만료 시간 저장 - $tokenExpiredDate');
    }
  }

  /// 로그인 정보 삭제
  Future<void> _clearAuthData() async {
    debugPrint('🔐 AuthService: 로그인 정보 삭제');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyTokenExpiredDate);
  }

  /// JWT의 exp(만료 시각)를 로컬에서 디코드해 만료 여부를 판단한다(서버 호출 없음).
  /// 형식이 이상하거나 파싱 실패면 만료로 간주한다.
  bool _isJwtExpired(String? token) {
    if (token == null || token.isEmpty) return true;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final map =
          jsonDecode(utf8.decode(base64.decode(payload))) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp is! int) return true;
      // exp는 epoch seconds. 경계 오차 방지를 위해 30초 여유를 두고 미리 만료 처리.
      final expMs = exp * 1000 - 30000;
      return DateTime.now().millisecondsSinceEpoch >= expMs;
    } catch (_) {
      return true;
    }
  }

  /// 현재 저장된 토큰의 만료 여부(비로그인/토큰없음도 만료로 취급).
  Future<bool> isTokenExpired() async {
    final prefs = await SharedPreferences.getInstance();
    return _isJwtExpired(prefs.getString(_keyToken));
  }

  /// 로그인 상태인데 토큰이 만료됐으면 로컬 로그아웃 처리하고 true를 반환한다.
  /// (메인 메뉴 탭 등에서 호출 → "로그인 표시되는데 실제론 만료" 상태를 해소)
  /// 서버 호출 없이 로컬만 정리한다(만료 토큰은 서버 로그아웃도 어차피 거부됨).
  Future<bool> enforceTokenValidity() async {
    if (_authStatus != AuthStatus.authenticated) return false;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    if (!_isJwtExpired(token)) return false; // 유효 → 그대로 둠
    debugPrint('🔐 AuthService: 토큰 만료 감지 → 자동 로그아웃(로컬)');
    _token = null;
    _currentUser = null;
    _authStatus = AuthStatus.unauthenticated;
    await _clearAuthData();
    notifyListeners();
    return true;
  }

  /// 서버가 응답 헤더('auth-token')로 재발급해준 새 토큰을 저장한다.
  /// 사용 중 매 요청마다 갱신되므로, 앱을 계속 쓰면 토큰이 만료되지 않는다(A).
  Future<void> saveRefreshedToken(String newToken) async {
    if (newToken.isEmpty || _authStatus != AuthStatus.authenticated) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_keyToken) == newToken) return; // 동일하면 스킵
    _token = newToken;
    await prefs.setString(_keyToken, newToken);
    debugPrint('🔐 AuthService: 토큰 자동 갱신 저장');
  }

  /// 회원탈퇴 시 모든 인증 정보 삭제 (registered_email 포함)
  Future<void> _clearAllAuthData() async {
    debugPrint('🔐 AuthService: 모든 인증 정보 삭제 (회원탈퇴)');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyRegisteredEmail);
    debugPrint('🔐 AuthService: registered_email 삭제 완료');
  }

  @override
  Future<User> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    debugPrint('🔐 AuthService: 이메일 로그인 시도 - $email');

    try {
      _authStatus = AuthStatus.loading;
      notifyListeners();

      // UUID 가져오기
      final uuid = await getDeviceUuid();
      debugPrint('🔐 AuthService: 로그인 UUID - $uuid');

      final response = await _apiService.login(
        email: email,
        password: password,
        uuid: uuid,
      );

      // 응답에서 토큰과 사용자 정보 추출
      final token = response['authToken'] as String?;
      final userId = response['memberId'] as String? ?? email;
      final tokenExpiredDate = response['tokenExpiredDate'] as int?;

      if (token == null) {
        throw Exception('로그인 응답에 authToken이 없습니다');
      }

      debugPrint('🔐 AuthService: 로그인 토큰 받음 - 만료일: $tokenExpiredDate');

      // 사용자 객체 생성
      final user = User(
        id: userId,
        email: email,
        createdAt: DateTime.now(),
      );

      // 로그인 정보 저장
      _token = token;
      _currentUser = user;
      _authStatus = AuthStatus.authenticated;

      await _saveAuthData(
        token: token,
        email: email,
        userId: userId,
        tokenExpiredDate: tokenExpiredDate,
      );

      // 서버에서 구독 플랜 조회 후 저장
      await _fetchAndSaveSubscriptionPlan(token: token);

      // 게스트(device-uuid) 데이터를 회원으로 이관 (최초 로그인 시 1회)
      await _migrateGuestDataOnce(token);

      notifyListeners();
      debugPrint('🔐 AuthService: 로그인 성공 - $email');

      return _currentUser!;
    } catch (e) {
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
      debugPrint('🔐 AuthService: 로그인 실패 - $e');
      rethrow;
    }
  }

  @override
  Future<User> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    debugPrint('🔐 AuthService: 이메일 회원가입 시도 - $email');

    try {
      _authStatus = AuthStatus.loading;
      notifyListeners();

      // 디바이스 UUID 가져오기 또는 생성
      final uuid = await _getOrCreateDeviceUuid();

      final response = await _apiService.signUp(
        email: email,
        password: password,
        uuid: uuid,
        nickname: displayName, // 선택 닉네임 — 서버가 name 컬럼에 중복 검증 후 저장
      );

      // 응답에서 사용자 정보 추출
      final userId = response['userId'] as String? ?? email;

      // 사용자 객체 생성
      final user = User(
        id: userId,
        email: email,
        displayName: displayName,
        createdAt: DateTime.now(),
      );

      // 최초 회원가입한 이메일 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRegisteredEmail, email);
      debugPrint('🔐 AuthService: 회원가입 이메일 저장 - $email');

      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
      debugPrint('🔐 AuthService: 회원가입 성공 - $email');

      return user;
    } catch (e) {
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
      debugPrint('🔐 AuthService: 회원가입 실패 - $e');
      rethrow;
    }
  }

  @override
  Future<User> signInWithGoogle() async {
    debugPrint('🔐 AuthService: Google 로그인 시도');

    try {
      _authStatus = AuthStatus.loading;
      notifyListeners();

      // 1) 구글 계정 선택 → idToken 획득
      final googleSignIn = GoogleSignIn(
        scopes: const ['email'],
        serverClientId: _googleServerClientId,
      );
      // 이전 세션 캐시 제거로 계정 선택 화면 보장(계정 전환 대응)
      await googleSignIn.signOut();
      final account = await googleSignIn.signIn();
      if (account == null) {
        _authStatus = AuthStatus.unauthenticated;
        notifyListeners();
        throw Exception('Google 로그인이 취소되었습니다.');
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google idToken을 가져오지 못했습니다.');
      }

      return await _completeSocialLogin(
        provider: 'google',
        idToken: idToken,
        email: account.email,
        displayName: account.displayName,
      );
    } catch (e) {
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
      debugPrint('🔐 AuthService: Google 로그인 실패 - $e');
      rethrow;
    }
  }

  @override
  Future<User> signInWithApple() async {
    debugPrint('🔐 AuthService: Apple 로그인 시도');

    try {
      _authStatus = AuthStatus.loading;
      notifyListeners();

      // 1) 애플 로그인 → identityToken(idToken) 획득
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Apple identityToken을 가져오지 못했습니다.');
      }

      // 이름/이메일은 애플이 최초 1회만 제공(이후 로그인 시 null) — 서버 계정 생성 시에만 사용됨
      String? displayName;
      final given = credential.givenName;
      final family = credential.familyName;
      if ((given != null && given.isNotEmpty) ||
          (family != null && family.isNotEmpty)) {
        displayName = [given, family]
            .where((e) => e != null && e.isNotEmpty)
            .join(' ')
            .trim();
        if (displayName.isEmpty) displayName = null;
      }

      return await _completeSocialLogin(
        provider: 'apple',
        idToken: idToken,
        email: credential.email,
        displayName: displayName,
      );
    } catch (e) {
      _authStatus = AuthStatus.unauthenticated;
      notifyListeners();
      debugPrint('🔐 AuthService: Apple 로그인 실패 - $e');
      rethrow;
    }
  }

  /// 소셜 로그인 공통 마무리 — 서버에 idToken 검증 요청 후 자체 JWT 저장(이메일 로그인과 동일 흐름).
  Future<User> _completeSocialLogin({
    required String provider,
    required String idToken,
    String? email,
    String? displayName,
  }) async {
    final uuid = await getDeviceUuid();
    debugPrint('🔐 AuthService: 소셜 로그인 UUID - $uuid');

    final response = await _apiService.loginSocial(
      provider: provider,
      idToken: idToken,
      uuid: uuid,
    );

    final token = response['authToken'] as String?;
    final memberId =
        response['memberId'] as String? ?? email ?? '$provider-user';
    final tokenExpiredDate = response['tokenExpiredDate'] as int?;
    final serverName = response['name'] as String?;

    if (token == null) {
      throw Exception('소셜 로그인 응답에 authToken이 없습니다');
    }

    final user = User(
      id: memberId,
      email: email ?? memberId,
      displayName: serverName ?? displayName,
      createdAt: DateTime.now(),
    );

    _token = token;
    _currentUser = user;
    _authStatus = AuthStatus.authenticated;

    await _saveAuthData(
      token: token,
      email: user.email,
      userId: memberId,
      tokenExpiredDate: tokenExpiredDate,
    );

    // 서버에서 구독 플랜 조회 후 저장
    await _fetchAndSaveSubscriptionPlan(token: token);
    // 게스트(device-uuid) 데이터를 회원으로 이관 (최초 로그인 시 1회)
    await _migrateGuestDataOnce(token);

    notifyListeners();
    debugPrint('🔐 AuthService: 소셜 로그인 성공 - $provider / $memberId');
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    debugPrint('🔐 AuthService: 로그아웃');

    // 서버에 디바이스 슬롯(uuid1/2/3) 해제 요청 — 1계정 3장치 슬롯 반납.
    // 실패해도(오프라인 등) 로컬 로그아웃은 그대로 진행한다.
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = _token ?? prefs.getString(_keyToken);
      if (token != null) {
        final uuid = await getDeviceUuid();
        final ok = await _apiService.logout(token: token, deviceUuid: uuid);
        debugPrint('🔐 AuthService: 서버 로그아웃(슬롯 해제) 결과 - $ok');
      }
    } catch (e) {
      debugPrint('🔐 AuthService: 서버 로그아웃 실패(무시하고 로컬 로그아웃 진행) - $e');
    }

    _token = null;
    _authStatus = AuthStatus.unauthenticated;
    _currentUser = null;

    await _clearAuthData();
    notifyListeners();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    debugPrint('🔐 AuthService: 비밀번호 재설정 이메일 전송 - $email');

    try {
      await _apiService.sendPasswordResetEmail(email: email);
      debugPrint('🔐 AuthService: 비밀번호 재설정 이메일 전송 성공');
    } catch (e) {
      debugPrint('🔐 AuthService: 비밀번호 재설정 이메일 전송 실패 - $e');
      rethrow;
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    debugPrint('🔐 AuthService: 비밀번호 변경');

    if (_currentUser == null) {
      throw Exception('로그인이 필요합니다');
    }

    try {
      await _apiService.changePassword(
        email: _currentUser!.email,
        currentPassword: currentPassword,
        newPassword: newPassword,
        token: _token,
      );
      debugPrint('🔐 AuthService: 비밀번호 변경 성공');
    } catch (e) {
      debugPrint('🔐 AuthService: 비밀번호 변경 실패 - $e');
      rethrow;
    }
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    debugPrint('🔐 AuthService: 프로필 업데이트');

    // TODO: 2차 개발 시 백엔드 API 연동
    throw UnimplementedError('프로필 업데이트 기능은 2차 개발에서 구현됩니다.');
  }

  @override
  Future<void> deleteAccount() async {
    debugPrint('🔐 AuthService: 계정 삭제');

    if (_currentUser == null) {
      throw Exception('로그인이 필요합니다');
    }

    try {
      await _apiService.deleteAccount(
        email: _currentUser!.email,
        token: _token,
      );

      // 로그아웃 처리 및 registered_email 삭제
      _token = null;
      _authStatus = AuthStatus.unauthenticated;
      _currentUser = null;

      await _clearAllAuthData();
      notifyListeners();

      debugPrint('🔐 AuthService: 계정 삭제 성공');
    } catch (e) {
      debugPrint('🔐 AuthService: 계정 삭제 실패 - $e');
      rethrow;
    }
  }

  /// 회원탈퇴 (로컬 파일 유지, 무료 플랜 전환)
  Future<void> deleteAccountAndAllData() async {
    debugPrint('🔐 AuthService: 회원탈퇴 (로컬 파일 유지, 무료 플랜 전환)');

    if (_currentUser == null) {
      throw Exception('로그인이 필요합니다');
    }

    try {
      // 1. 서버에 회원탈퇴 요청
      await _apiService.deleteAccount(
        email: _currentUser!.email,
        token: _token,
      );
      debugPrint('🔐 AuthService: 서버 회원탈퇴 완료');

      // 2. 로그아웃 처리 및 인증 정보 삭제
      _token = null;
      _authStatus = AuthStatus.unauthenticated;
      _currentUser = null;

      await _clearAllAuthData();
      debugPrint('🔐 AuthService: 인증 정보 삭제 완료');

      // 3. 로컬 파일은 유지 (삭제하지 않음)
      debugPrint('ℹ️ AuthService: 로컬 파일 유지');

      // 4. 무료 플랜으로 전환
      await _resetToFreePlan();
      debugPrint('🔐 AuthService: 무료 플랜 전환 완료');

      notifyListeners();

      debugPrint('🔐 AuthService: 회원탈퇴 성공 (로컬 파일 유지, 무료 플랜)');
    } catch (e) {
      debugPrint('🔐 AuthService: 회원탈퇴 실패 - $e');
      rethrow;
    }
  }

  /// 모든 로컬 파일 삭제
  Future<void> _deleteAllLocalFiles() async {
    try {
      debugPrint('🗑️ AuthService: 로컬 파일 삭제 시작');

      // 앱 문서 디렉토리 가져오기
      final directory = await getApplicationDocumentsDirectory();
      final appDir = Directory(directory.path);

      // 모든 파일과 디렉토리 삭제
      if (await appDir.exists()) {
        final files = appDir.listSync(recursive: true);
        for (final file in files) {
          try {
            if (file is File) {
              await file.delete();
              debugPrint('🗑️ 파일 삭제: ${file.path}');
            } else if (file is Directory) {
              await file.delete(recursive: true);
              debugPrint('🗑️ 디렉토리 삭제: ${file.path}');
            }
          } catch (e) {
            debugPrint('⚠️ 파일 삭제 실패: ${file.path} - $e');
          }
        }
      }

      // SharedPreferences의 모든 파일 관련 데이터 삭제
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.contains('text_files_') ||
            key.contains('handwriting_files_') ||
            key.contains('audio_files_') ||
            key.contains('littens')) {
          await prefs.remove(key);
          debugPrint('🗑️ SharedPreferences 키 삭제: $key');
        }
      }

      debugPrint('✅ AuthService: 모든 로컬 파일 삭제 완료');
    } catch (e) {
      debugPrint('❌ AuthService: 로컬 파일 삭제 실패 - $e');
      rethrow;
    }
  }

  /// 서버에서 구독 플랜 조회 후 로컬 저장 및 User 객체 업데이트
  Future<void> _fetchAndSaveSubscriptionPlan({required String token}) async {
    try {
      debugPrint('🔄 AuthService: 서버에서 구독 플랜 조회 시작');
      final planStr = await _apiService.getSubscriptionPlan(token: token);
      final plan = SubscriptionPlan.values.firstWhere(
        (p) => p.name == planStr,
        orElse: () => SubscriptionPlan.free,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySubscriptionPlan, planStr);
      _currentUser = _currentUser?.copyWith(subscriptionPlan: plan);
      debugPrint('✅ AuthService: 구독 플랜 저장 완료 - $planStr');
    } catch (e) {
      debugPrint('⚠️ AuthService: 구독 플랜 조회 실패 (free 유지) - $e');
    }
  }

  /// 게스트(device-uuid) 데이터를 로그인 회원으로 이관 — 로그인할 때마다 실행.
  /// migrate는 멱등(이관할 게 없으면 0건)이라 매번 호출해도 안전하며,
  /// 로그아웃 후 게스트 상태에서 추가한 영상구독/요약도 재로그인 시 회원으로 이관된다.
  /// (1회 플래그 방식은 첫 로그인 이후 등록한 게스트 데이터를 누락시켜 제거함)
  Future<void> _migrateGuestDataOnce(String token) async {
    final uuid = await getDeviceUuid();
    debugPrint('🔐 AuthService: 게스트 데이터 이관 시작 - uuid: $uuid');
    final ok = await _apiService.migrateGuestData(token: token, deviceUuid: uuid);
    debugPrint(ok
        ? '🔐 AuthService: 게스트 데이터 이관 완료'
        : '🔐 AuthService: 게스트 데이터 이관 실패 (다음 로그인 시 재시도)');
  }

  /// 닉네임 변경 (서버 중복 검증 후 반영). 반환: (ok, message?).
  Future<({bool ok, String? message})> updateNickname(String nickname) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return (ok: false, message: '로그인이 필요합니다.');
    }
    final r = await _apiService.updateNickname(token: token, nickname: nickname);
    if (r['result'] == 1) {
      _currentUser = _currentUser?.copyWith(displayName: r['name']?.toString());
      notifyListeners();
      debugPrint('🔐 AuthService: 닉네임 변경 성공 - ${r['name']}');
      return (ok: true, message: null);
    }
    return (ok: false, message: r['message']?.toString() ?? '닉네임 변경에 실패했습니다.');
  }

  /// 닉네임 중복 확인 — 사용 가능하면 true.
  Future<bool> checkNicknameAvailable(String nickname) =>
      _apiService.checkNicknameAvailable(nickname);

  /// 회원가입 이메일 인증번호 발송. 반환: {result, message}.
  Future<Map<String, dynamic>> sendSignupEmailCode(String email,
          {String lanCd = 'KR'}) =>
      _apiService.sendSignupEmailCode(email: email, lanCd: lanCd);

  /// 회원가입 이메일 인증번호 검증. 반환: {result, message}.
  Future<Map<String, dynamic>> verifySignupEmailCode(String email, String code) =>
      _apiService.verifySignupEmailCode(email: email, code: code);

  /// 1:1 채팅 상대 검색(이메일/닉네임). 반환: {found:bool, id?, name?}.
  Future<Map<String, dynamic>> searchMember(String query) =>
      _apiService.searchMember(query);

  /// 로컬 구독 플랜 업데이트 (메모리 + SharedPreferences, 서버 API 없이)
  Future<void> updateLocalSubscriptionPlan(SubscriptionPlan plan) async {
    debugPrint('🔐 AuthService: 로컬 구독 플랜 업데이트 - ${plan.name}');
    _currentUser = _currentUser?.copyWith(subscriptionPlan: plan);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySubscriptionPlan, plan.name);
    notifyListeners();
    debugPrint('✅ AuthService: 로컬 구독 플랜 업데이트 완료 - ${plan.name}');
  }

  /// 서버 DB에 구독 플랜 반영. 모든 플랜 전환(free↔standard↔premium)을 서버에 일치시킨다.
  /// 식별자 우선순위: 토큰(로그인) → 가입 이메일(registered_email) → device_uuid(설치 시 서버 등록).
  /// - 로그인: JWT 기반 PUT /members/plan
  /// - 로그아웃/비로그인: id 기반 PUT /members/plan/by-id
  ///   가입 이메일이 없으면 device_uuid로 식별 → 미가입 비로그인 상태에서도 모든 플랜 변경을
  ///   서버 DB에 반영(구독 변경 자유). device_uuid 행은 앱 설치 시 install API로 서버에 생성됨.
  Future<bool> updateServerSubscriptionPlan(SubscriptionPlan plan, {DateTime? expiredAt}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = _token ?? prefs.getString(_keyToken);
    if (token != null) {
      final ok = await _apiService.updateSubscriptionPlan(
        plan: plan.name,
        token: token,
        planExpiredAt: expiredAt?.toIso8601String(),
      );
      debugPrint('🔐 AuthService: 서버 구독 플랜 업데이트(토큰) - ${plan.name}, 결과: $ok');
      return ok;
    }
    // 로그아웃/비로그인 — 가입 이메일 우선, 없으면 device_uuid(항상 존재)로 식별
    String? id = prefs.getString(_keyRegisteredEmail);
    if (id == null || id.isEmpty) {
      id = await getDeviceUuid();
    }
    if (id == null || id.isEmpty) {
      debugPrint('🔐 AuthService: 서버 구독 플랜 업데이트 스킵 (식별자 없음) - ${plan.name}');
      return false;
    }
    final ok = await _apiService.updateSubscriptionPlanById(
      id: id,
      plan: plan.name,
      planExpiredAt: expiredAt?.toIso8601String(),
    );
    debugPrint('🔐 AuthService: 서버 구독 플랜 업데이트(by-id) - id: $id, ${plan.name}, 결과: $ok');
    return ok;
  }

  /// 무료 플랜으로 전환
  Future<void> _resetToFreePlan() async {
    try {
      debugPrint('🔄 AuthService: 무료 플랜으로 전환 시작');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySubscriptionPlan, 'free');
      _currentUser = _currentUser?.copyWith(subscriptionPlan: SubscriptionPlan.free);

      debugPrint('✅ AuthService: 무료 플랜 전환 완료');
    } catch (e) {
      debugPrint('❌ AuthService: 무료 플랜 전환 실패 - $e');
      rethrow;
    }
  }

  @override
  Stream<User?> get authStateChanges {
    // TODO: 2차 개발 시 실제 인증 상태 스트림 반환
    return Stream.value(null);
  }
}
