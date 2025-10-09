import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// 인증 상태를 나타내는 열거형
enum AuthStatus {
  authenticated,    // 인증됨
  unauthenticated, // 인증되지 않음
  loading,         // 로딩 중
}

/// 사용자 모델
class User {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
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
  final ApiService _apiService = ApiService();

  // SharedPreferences 키
  static const String _keyToken = 'auth_token';
  static const String _keyEmail = 'user_email';
  static const String _keyUserId = 'user_id';

  @override
  AuthStatus get authStatus => _authStatus;

  @override
  User? get currentUser => _currentUser;

  /// 로그인 상태 확인
  Future<void> checkAuthStatus() async {
    debugPrint('🔐 AuthService: 로그인 상태 확인');

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_keyToken);
      final email = prefs.getString(_keyEmail);
      final userId = prefs.getString(_keyUserId);

      if (token != null && email != null && userId != null) {
        _token = token;
        _currentUser = User(
          id: userId,
          email: email,
          createdAt: DateTime.now(),
        );
        _authStatus = AuthStatus.authenticated;
        debugPrint('🔐 AuthService: 로그인 상태 - $email');
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
  }) async {
    debugPrint('🔐 AuthService: 로그인 정보 저장 - $email');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyUserId, userId);
  }

  /// 로그인 정보 삭제
  Future<void> _clearAuthData() async {
    debugPrint('🔐 AuthService: 로그인 정보 삭제');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyUserId);
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

      final response = await _apiService.login(
        email: email,
        password: password,
      );

      // 응답에서 토큰과 사용자 정보 추출
      final token = response['token'] as String? ?? 'dummy_token';
      final userId = response['userId'] as String? ?? email;

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
      );

      notifyListeners();
      debugPrint('🔐 AuthService: 로그인 성공 - $email');

      return user;
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

      final response = await _apiService.signUp(
        email: email,
        password: password,
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

    // TODO: 2차 개발 시 백엔드 API 연동
    throw UnimplementedError('계정 삭제 기능은 2차 개발에서 구현됩니다.');
  }

  @override
  Stream<User?> get authStateChanges {
    // TODO: 2차 개발 시 실제 인증 상태 스트림 반환
    return Stream.value(null);
  }
}
