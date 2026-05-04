import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
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

  User copyWith({SubscriptionPlan? subscriptionPlan}) {
    return User(
      id: id,
      email: email,
      displayName: displayName,
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

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_keyToken);
      final email = prefs.getString(_keyEmail);
      final userId = prefs.getString(_keyUserId);

      // 디바이스 UUID 확인 또는 생성
      await _getOrCreateDeviceUuid();

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

    // TODO: 2차 개발 시 Google Sign-In 연동
    throw UnimplementedError('Google 로그인 기능은 2차 개발에서 구현됩니다.');
  }

  @override
  Future<User> signInWithApple() async {
    debugPrint('🔐 AuthService: Apple 로그인 시도');

    // TODO: 2차 개발 시 Apple Sign-In 연동
    throw UnimplementedError('Apple 로그인 기능은 2차 개발에서 구현됩니다.');
  }

  @override
  Future<void> signOut() async {
    debugPrint('🔐 AuthService: 로그아웃');

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

  /// 로컬 구독 플랜 업데이트 (메모리 + SharedPreferences, 서버 API 없이)
  Future<void> updateLocalSubscriptionPlan(SubscriptionPlan plan) async {
    debugPrint('🔐 AuthService: 로컬 구독 플랜 업데이트 - ${plan.name}');
    _currentUser = _currentUser?.copyWith(subscriptionPlan: plan);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySubscriptionPlan, plan.name);
    notifyListeners();
    debugPrint('✅ AuthService: 로컬 구독 플랜 업데이트 완료 - ${plan.name}');
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
