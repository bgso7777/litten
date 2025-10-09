import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/app_state_provider.dart';

/// 비밀번호 재설정 화면
/// 이메일을 입력받아 비밀번호 재설정 링크를 전송합니다.
/// TODO: 2차 개발 시 백엔드 연동 및 실제 이메일 전송 기능 구현
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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

  /// 비밀번호 재설정 이메일 전송
  Future<void> _handleSendResetEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);

      await appState.authService.sendPasswordResetEmail(_emailController.text);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _emailSent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이메일 전송 실패: $e'),
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
        title: Text(AppLocalizations.of(context)?.forgotPassword ?? '비밀번호 찾기'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _emailSent ? _buildSuccessView(theme) : _buildFormView(theme),
        ),
      ),
    );
  }

  /// 이메일 입력 폼 뷰
  Widget _buildFormView(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),

          // 아이콘
          Icon(
            Icons.lock_reset,
            size: 80,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 32),

          // 제목
          Text(
            AppLocalizations.of(context)?.forgotPassword ?? '비밀번호 찾기',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // 설명
          Text(
            AppLocalizations.of(context)?.forgotPasswordDescription ??
                '가입하신 이메일 주소를 입력하시면\n비밀번호 재설정 링크를 보내드립니다',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
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
            textInputAction: TextInputAction.done,
            validator: _validateEmail,
            enabled: !_isLoading,
            onFieldSubmitted: (_) => _handleSendResetEmail(),
          ),
          const SizedBox(height: 32),

          // 전송 버튼
          FilledButton(
            onPressed: _isLoading ? null : _handleSendResetEmail,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    AppLocalizations.of(context)?.sendResetLink ?? '재설정 링크 전송',
                    style: const TextStyle(fontSize: 16),
                  ),
          ),
          const SizedBox(height: 16),

          // 로그인으로 돌아가기
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)?.backToLogin ?? '로그인으로 돌아가기',
            ),
          ),
        ],
      ),
    );
  }

  /// 이메일 전송 성공 뷰
  Widget _buildSuccessView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),

        // 성공 아이콘
        Icon(
          Icons.mark_email_read_outlined,
          size: 80,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 32),

        // 제목
        Text(
          AppLocalizations.of(context)?.emailSent ?? '이메일이 전송되었습니다',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // 설명
        Text(
          AppLocalizations.of(context)?.resetEmailSentDescription(_emailController.text) ??
              '${_emailController.text}로\n비밀번호 재설정 링크를 보내드렸습니다.\n\n이메일을 확인하시고 링크를 클릭하여\n새로운 비밀번호를 설정해주세요.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // 안내 메시지
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)?.resetEmailNote ??
                      '이메일이 도착하지 않았다면 스팸함을 확인해주세요',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),

        // 이메일 재전송 버튼
        OutlinedButton(
          onPressed: () {
            setState(() => _emailSent = false);
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            AppLocalizations.of(context)?.resendEmail ?? '이메일 다시 보내기',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 16),

        // 로그인으로 돌아가기
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            AppLocalizations.of(context)?.backToLogin ?? '로그인으로 돌아가기',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
