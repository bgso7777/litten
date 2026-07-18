import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/app_state_provider.dart';
import 'main_tab_screen.dart';

/// 회원가입 화면
/// 이메일과 비밀번호를 입력받아 회원가입을 진행합니다.
/// TODO: 2차 개발 시 백엔드 연동 및 실제 회원가입 기능 구현
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool? _nicknameAvailable; // null=미확인, true=사용가능, false=중복
  bool _nicknameChecking = false;

  // 이메일 인증 상태
  bool _codeSent = false; // 인증번호 발송됨
  bool _emailVerified = false; // 인증번호 검증 완료
  bool _sendingCode = false; // 인증번호 발송 중
  bool _verifyingCode = false; // 인증번호 검증 중

  /// 메일 템플릿 언어코드 — 현재 로케일이 한국어면 KR, 그 외 EN.
  String get _mailLanCd =>
      Localizations.localeOf(context).languageCode == 'ko' ? 'KR' : 'EN';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// 닉네임 중복확인 (선택 입력 — 비어 있으면 확인 불필요)
  Future<void> _checkNickname() async {
    final nick = _nicknameController.text.trim();
    if (nick.isEmpty) return;
    setState(() => _nicknameChecking = true);
    final available =
        await Provider.of<AppStateProvider>(context, listen: false)
            .authService
            .checkNicknameAvailable(nick);
    if (!mounted) return;
    setState(() {
      _nicknameChecking = false;
      _nicknameAvailable = available;
    });
  }

  /// 이메일 유효성 검사
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context)?.emailRequired ?? '이메일을 입력해주세요';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return AppLocalizations.of(context)?.emailInvalid ?? '올바른 이메일 형식이 아닙니다';
    }
    return null;
  }

  /// 비밀번호 유효성 검사
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context)?.passwordRequired ?? '비밀번호를 입력해주세요';
    }
    if (value.length < 6) {
      return AppLocalizations.of(context)?.passwordTooShort ?? '비밀번호는 최소 6자 이상이어야 합니다';
    }
    return null;
  }

  /// 비밀번호 확인 유효성 검사
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context)?.confirmPasswordRequired ?? '비밀번호 확인을 입력해주세요';
    }
    if (value != _passwordController.text) {
      return AppLocalizations.of(context)?.passwordMismatch ?? '비밀번호가 일치하지 않습니다';
    }
    return null;
  }

  /// 이메일 인증번호 발송
  Future<void> _sendCode() async {
    // 이메일 형식을 먼저 검증
    final emailError = _validateEmail(_emailController.text);
    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emailError), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _sendingCode = true);
    try {
      final res = await Provider.of<AppStateProvider>(context, listen: false)
          .authService
          .sendSignupEmailCode(_emailController.text.trim(), lanCd: _mailLanCd);
      if (!mounted) return;
      if (res['result'] == 1) {
        setState(() {
          _codeSent = true;
          _emailVerified = false;
          _codeController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('인증번호를 이메일로 발송했습니다. 메일함을 확인해주세요.')),
        );
      } else {
        final msg = (res['message'] as String?) ?? '인증번호 발송에 실패했습니다.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  /// 이메일 인증번호 검증
  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증번호를 입력해주세요.')),
      );
      return;
    }

    setState(() => _verifyingCode = true);
    try {
      final res = await Provider.of<AppStateProvider>(context, listen: false)
          .authService
          .verifySignupEmailCode(_emailController.text.trim(), code);
      if (!mounted) return;
      if (res['result'] == 1) {
        setState(() => _emailVerified = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이메일 인증이 완료되었습니다.')),
        );
      } else {
        final msg = (res['message'] as String?) ?? '인증번호가 올바르지 않습니다.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _verifyingCode = false);
    }
  }

  /// 회원가입 처리
  Future<void> _handleSignUp() async {
    // 이메일 인증 완료 필수
    if (!_emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일 인증을 완료해주세요.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final nick = _nicknameController.text.trim();
    // 닉네임을 입력한 경우 중복확인(사용 가능) 필수
    if (nick.isNotEmpty && _nicknameAvailable != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임 중복확인을 해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);

      await appState.authService.signUpWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: nick.isEmpty ? null : nick,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        // 회원가입 성공 시 로그인 화면으로 돌아가기
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.signUpComingSoon ?? '회원가입이 완료되었습니다. 로그인해주세요.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('회원가입 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 소셜 가입/로그인 처리 (Google) — 소셜은 가입=로그인(계정 없으면 자동 생성)
  Future<void> _handleGoogleSignUp() => _handleSocialSignUp('google');

  /// 소셜 가입/로그인 처리 (Apple)
  Future<void> _handleAppleSignUp() => _handleSocialSignUp('apple');

  /// 소셜 가입/로그인 공통 처리 — 성공 시 로그인 완료 상태로 홈 이동
  Future<void> _handleSocialSignUp(String provider) async {
    setState(() => _isLoading = true);

    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);

      switch (provider) {
        case 'apple':
          await appState.authService.signInWithApple(allowSignup: true);
          break;
        case 'kakao':
          await appState.authService.signInWithKakao(allowSignup: true);
          break;
        case 'naver':
          await appState.authService.signInWithNaver(allowSignup: true);
          break;
        default:
          await appState.authService.signInWithGoogle(allowSignup: true);
      }

      if (mounted) {
        // 소셜 가입/로그인 성공 → 로그인 완료 상태이므로 홈으로 이동(스택 정리)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainTabScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final msg = e.toString();
        // 사용자가 취소한 경우는 조용히 무시
        if (msg.contains('취소') ||
            msg.contains('canceled') ||
            msg.contains('cancelled')) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.loginFailed(msg) ?? '로그인 실패: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.signUp ?? '회원가입'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 32),

                      Text(
                        AppLocalizations.of(context)?.signUpDescription ??
                            '무료로 계정을 만들고 시작하세요',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)?.signUpEmailNote ??
                            '본인의 이메일을 넣으셔야 서비스 이용이 원활합니다',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),

                      // 이메일 입력 + 인증번호 발송
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)?.email ?? '이메일',
                          hintText: AppLocalizations.of(context)?.emailHint ?? 'example@email.com',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: const OutlineInputBorder(),
                          suffixIcon: _emailVerified
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(Icons.check_circle,
                                      color: Colors.green, size: 20),
                                )
                              : _sendingCode
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2)),
                                    )
                                  : TextButton(
                                      onPressed: _isLoading ? null : _sendCode,
                                      child: Text(_codeSent ? '재발송' : '인증번호 발송'),
                                    ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: _validateEmail,
                        // 인증 완료 후에는 이메일 변경 불가(재인증 방지)
                        enabled: !_isLoading && !_emailVerified,
                        onChanged: (_) {
                          // 이메일을 바꾸면 발송/인증 상태를 초기화
                          if (_codeSent || _emailVerified) {
                            setState(() {
                              _codeSent = false;
                              _emailVerified = false;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // 인증번호 입력 (발송 후 & 미인증 상태에서만 표시)
                      if (_codeSent && !_emailVerified) ...[
                        TextFormField(
                          controller: _codeController,
                          decoration: InputDecoration(
                            labelText: '인증번호',
                            hintText: '이메일로 받은 6자리 숫자',
                            prefixIcon: const Icon(Icons.verified_outlined),
                            border: const OutlineInputBorder(),
                            suffixIcon: _verifyingCode
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)),
                                  )
                                : TextButton(
                                    onPressed: _isLoading ? null : _verifyCode,
                                    child: const Text('확인'),
                                  ),
                          ),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          maxLength: 6,
                          enabled: !_isLoading,
                          onFieldSubmitted: (_) => _verifyCode(),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 4, left: 4, bottom: 12),
                          child: Text('인증번호는 발송 후 10분간 유효합니다.',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                      ],

                      // 인증 완료 안내
                      if (_emailVerified)
                        const Padding(
                          padding: EdgeInsets.only(top: 4, left: 4, bottom: 12),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green, size: 16),
                              SizedBox(width: 4),
                              Text('이메일 인증이 완료되었습니다.',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.green)),
                            ],
                          ),
                        ),

                      // 닉네임 입력 (선택) + 중복확인
                      TextFormField(
                        controller: _nicknameController,
                        decoration: InputDecoration(
                          labelText: '닉네임 (선택)',
                          hintText: '다른 사용자에게 표시될 이름',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: const OutlineInputBorder(),
                          suffixIcon: _nicknameChecking
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : TextButton(
                                  onPressed: _isLoading ? null : _checkNickname,
                                  child: const Text('중복확인'),
                                ),
                        ),
                        textInputAction: TextInputAction.next,
                        enabled: !_isLoading,
                        onChanged: (_) {
                          if (_nicknameAvailable != null) {
                            setState(() => _nicknameAvailable = null);
                          }
                        },
                      ),
                      if (_nicknameAvailable == true)
                        const Padding(
                          padding: EdgeInsets.only(top: 4, left: 4),
                          child: Text('사용 가능한 닉네임입니다.',
                              style: TextStyle(fontSize: 12, color: Colors.green)),
                        ),
                      if (_nicknameAvailable == false)
                        const Padding(
                          padding: EdgeInsets.only(top: 4, left: 4),
                          child: Text('이미 사용 중인 닉네임입니다.',
                              style: TextStyle(fontSize: 12, color: Colors.red)),
                        ),
                      const SizedBox(height: 16),

                      // 비밀번호 입력
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)?.password ?? '비밀번호',
                          hintText: AppLocalizations.of(context)?.passwordHint ?? '비밀번호를 입력하세요',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: !_isPasswordVisible,
                        textInputAction: TextInputAction.next,
                        validator: _validatePassword,
                        enabled: !_isLoading && _emailVerified,
                      ),
                      const SizedBox(height: 16),

                      // 비밀번호 확인 입력
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)?.confirmPassword ?? '비밀번호 확인',
                          hintText: AppLocalizations.of(context)?.confirmPasswordHint ?? '비밀번호를 다시 입력하세요',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: !_isConfirmPasswordVisible,
                        textInputAction: TextInputAction.done,
                        validator: _validateConfirmPassword,
                        enabled: !_isLoading && _emailVerified,
                        onFieldSubmitted: (_) => _handleSignUp(),
                      ),
                      const SizedBox(height: 32),

                      // 회원가입 버튼 (이메일 인증 완료 후 활성화)
                      FilledButton(
                        onPressed:
                            (_isLoading || !_emailVerified) ? null : _handleSignUp,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          AppLocalizations.of(context)?.signUp ?? '회원가입',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 구분선
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              AppLocalizations.of(context)?.orSignUpWith ?? '또는 다음으로 가입',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Google 회원가입 버튼
                      OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : _handleGoogleSignUp,
                        icon: const Icon(Icons.g_mobiledata, size: 24),
                        label: Text(
                          AppLocalizations.of(context)?.signUpWithGoogle ?? 'Google로 가입',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),

                      const SizedBox(height: 12),
                      // Apple 가입은 iOS에서만 동작 — 안드로이드에선 비활성(향후 활성화 작업 인지용)
                      Opacity(
                        opacity: Platform.isIOS ? 1.0 : 0.4,
                        child: OutlinedButton.icon(
                          onPressed: Platform.isIOS
                              ? (_isLoading ? null : _handleAppleSignUp)
                              : null,
                          icon: const Icon(Icons.apple, size: 24),
                          label: Text(
                            AppLocalizations.of(context)?.signUpWithApple ?? 'Apple로 가입',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Platform.isIOS ? null : Colors.grey[100],
                          ),
                        ),
                      ),
                      // 카카오·네이버는 한국어 앱에서만 노출
                      if (Localizations.localeOf(context).languageCode == 'ko') ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : () => _handleSocialSignUp('kakao'),
                          icon: const Icon(Icons.chat_bubble, size: 22, color: Color(0xFF3C1E1E)),
                          label: const Text('카카오로 가입'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: const Color(0xFFFEE500),
                            foregroundColor: const Color(0xFF3C1E1E),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : () => _handleSocialSignUp('naver'),
                          icon: const Icon(Icons.circle, size: 22, color: Colors.white),
                          label: const Text('네이버로 가입'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: const Color(0xFF03C75A),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),

                      // 로그인 링크
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context)?.alreadyHaveAccount ?? '이미 계정이 있으신가요?',
                            style: theme.textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              AppLocalizations.of(context)?.login ?? '로그인',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
