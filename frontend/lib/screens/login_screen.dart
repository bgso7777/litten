import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../services/app_state_provider.dart';
import '../services/api_service.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _registeredEmail; // 최초 회원가입한 이메일

  @override
  void initState() {
    super.initState();
    _loadRegisteredEmail();
  }

  /// SharedPreferences에서 등록된 이메일 불러오기
  Future<void> _loadRegisteredEmail() async {
    debugPrint(
      '[LoginScreen] _loadRegisteredEmail - SharedPreferences에서 이메일 조회',
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('registered_email');

      debugPrint('[LoginScreen] _loadRegisteredEmail - 저장된 이메일: $email');

      if (email != null && mounted) {
        setState(() {
          _registeredEmail = email;
          _emailController.text = email;
        });
        debugPrint('[LoginScreen] _loadRegisteredEmail - 이메일 고정: $email');
      } else {
        debugPrint('[LoginScreen] _loadRegisteredEmail - 저장된 이메일 없음');
      }
    } catch (e) {
      debugPrint('[LoginScreen] _loadRegisteredEmail - 오류 발생: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);

      await appState.authService.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (mounted) {
        // 로그인 성공 시 이전 화면으로 돌아가기
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.loginComingSoon ?? '로그인에 성공했습니다',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleSocialLogin(String provider) async {
    setState(() => _isLoading = true);

    // TODO: 2차 개발 시 소셜 로그인 구현
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.loginComingSoon ?? '로그인 기능은 곧 출시됩니다',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.login ?? '로그인'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            // 뒤로가기 버튼 클릭 시 홈 화면으로 이동
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/', (route) => false);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // 제목
                Text(
                  l10n?.welcomeBack ?? '다시 오신 것을 환영합니다',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n?.loginDescription ?? '계정에 로그인하여 클라우드 동기화를 이용하세요',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),

                // 이메일 입력
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: _registeredEmail == null, // 등록된 이메일이 있으면 비활성화
                  decoration: InputDecoration(
                    labelText: l10n?.email ?? '이메일',
                    hintText: l10n?.emailHint ?? 'example@email.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: _registeredEmail != null
                        ? '이 기기에 등록된 계정입니다'
                        : null,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n?.emailRequired ?? '이메일을 입력해주세요';
                    }
                    if (!value.contains('@')) {
                      return l10n?.emailInvalid ?? '올바른 이메일 형식이 아닙니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 비밀번호 입력
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: l10n?.password ?? '비밀번호',
                    hintText: l10n?.passwordHint ?? '비밀번호를 입력하세요',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        );
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n?.passwordRequired ?? '비밀번호를 입력해주세요';
                    }
                    if (value.length < 6) {
                      return l10n?.passwordTooShort ?? '비밀번호는 최소 6자 이상이어야 합니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // 로그인 버튼
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleEmailLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          l10n?.login ?? '로그인',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 12),

                // 비밀번호 찾기
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: Text(l10n?.forgotPassword ?? '비밀번호를 잊으셨나요?'),
                ),

                const SizedBox(height: 24),

                // 구분선
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l10n?.orLoginWith ?? '또는 다음으로 로그인',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
                const SizedBox(height: 24),

                // 소셜 로그인 버튼들 (2차 개발 예정)
                _buildSocialLoginButton(
                  icon: Icons.g_mobiledata,
                  label: l10n?.loginWithGoogle ?? 'Google로 로그인',
                  onPressed: null, // 비활성화
                  color: Colors.red,
                ),
                const SizedBox(height: 12),
                _buildSocialLoginButton(
                  icon: Icons.apple,
                  label: l10n?.loginWithApple ?? 'Apple로 로그인',
                  onPressed: null, // 비활성화
                  color: Colors.black,
                ),

                const SizedBox(height: 24),

                // 회원가입 링크
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n?.noAccount ?? '계정이 없으신가요? ',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpScreen(),
                          ),
                        );
                      },
                      child: Text(l10n?.signUp ?? '회원가입'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLoginButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    final isDisabled = onPressed == null;
    return Opacity(
      opacity: isDisabled ? 0.4 : 1.0, // 비활성화 시 투명도 40%
      child: OutlinedButton(
        onPressed: _isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: Colors.grey[300]!),
          backgroundColor: isDisabled ? Colors.grey[100] : null, // 비활성화 시 배경색 회색
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[800])),
          ],
        ),
      ),
    );
  }
}
