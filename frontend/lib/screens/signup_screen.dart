import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/app_state_provider.dart';

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

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool? _nicknameAvailable; // null=미확인, true=사용가능, false=중복
  bool _nicknameChecking = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
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

  /// 회원가입 처리
  Future<void> _handleSignUp() async {
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

  /// 소셜 로그인 처리 (Google)
  /// TODO: 2차 개발 시 AuthService의 signInWithGoogle() 호출
  Future<void> _handleGoogleSignUp() async {
    setState(() => _isLoading = true);

    // TODO: 2차 개발 시 백엔드 연동
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.signUpComingSoon ?? '회원가입 기능은 곧 출시됩니다',
          ),
        ),
      );
    }
  }

  /// 소셜 로그인 처리 (Apple)
  /// TODO: 2차 개발 시 AuthService의 signInWithApple() 호출
  Future<void> _handleAppleSignUp() async {
    setState(() => _isLoading = true);

    // TODO: 2차 개발 시 백엔드 연동
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.signUpComingSoon ?? '회원가입 기능은 곧 출시됩니다',
          ),
        ),
      );
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

                      // 환영 메시지
                      Text(
                        AppLocalizations.of(context)?.createAccount ?? '계정 만들기',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
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

                      // 이메일 입력
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)?.email ?? '이메일',
                          hintText: AppLocalizations.of(context)?.emailHint ?? 'example@email.com',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: _validateEmail,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),

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
                        enabled: !_isLoading,
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
                        enabled: !_isLoading,
                        onFieldSubmitted: (_) => _handleSignUp(),
                      ),
                      const SizedBox(height: 32),

                      // 회원가입 버튼
                      FilledButton(
                        onPressed: _isLoading ? null : _handleSignUp,
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

                      // Google 회원가입 버튼 (2차 개발 예정)
                      Opacity(
                        opacity: 0.4, // 비활성화 시 투명도 40%
                        child: OutlinedButton.icon(
                          onPressed: null, // 비활성화
                          icon: const Icon(Icons.g_mobiledata, size: 24),
                          label: Text(
                            AppLocalizations.of(context)?.signUpWithGoogle ?? 'Google로 가입',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.grey[100], // 비활성화 시 배경색 회색
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Apple 회원가입 버튼 (2차 개발 예정)
                      Opacity(
                        opacity: 0.4, // 비활성화 시 투명도 40%
                        child: OutlinedButton.icon(
                          onPressed: null, // 비활성화
                          icon: const Icon(Icons.apple, size: 24),
                          label: Text(
                            AppLocalizations.of(context)?.signUpWithApple ?? 'Apple로 가입',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.grey[100], // 비활성화 시 배경색 회색
                          ),
                        ),
                      ),
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
