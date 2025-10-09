import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/app_state_provider.dart';

/// 비밀번호 변경 화면
/// 현재 비밀번호와 새 비밀번호를 입력받아 비밀번호를 변경합니다.
/// TODO: 2차 개발 시 백엔드 연동 및 실제 비밀번호 변경 기능 구현
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();

  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmNewPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  /// 현재 비밀번호 유효성 검사
  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context)?.currentPasswordRequired ?? '현재 비밀번호를 입력해주세요';
    }
    if (value.length < 6) {
      return AppLocalizations.of(context)?.passwordTooShort ?? '비밀번호는 최소 6자 이상이어야 합니다';
    }
    return null;
  }

  /// 새 비밀번호 유효성 검사
  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context)?.newPasswordRequired ?? '새 비밀번호를 입력해주세요';
    }
    if (value.length < 6) {
      return AppLocalizations.of(context)?.passwordTooShort ?? '비밀번호는 최소 6자 이상이어야 합니다';
    }
    if (value == _currentPasswordController.text) {
      return AppLocalizations.of(context)?.newPasswordSameAsCurrent ?? '새 비밀번호가 현재 비밀번호와 같습니다';
    }
    return null;
  }

  /// 새 비밀번호 확인 유효성 검사
  String? _validateConfirmNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context)?.confirmPasswordRequired ?? '비밀번호 확인을 입력해주세요';
    }
    if (value != _newPasswordController.text) {
      return AppLocalizations.of(context)?.passwordMismatch ?? '비밀번호가 일치하지 않습니다';
    }
    return null;
  }

  /// 비밀번호 변경 처리
  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);

      await appState.authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.passwordChanged ?? '비밀번호가 변경되었습니다',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('비밀번호 변경 실패: $e'),
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
        title: Text(AppLocalizations.of(context)?.changePassword ?? '비밀번호 변경'),
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
                                AppLocalizations.of(context)?.changePasswordInfo ??
                                    '보안을 위해 주기적으로 비밀번호를 변경해주세요',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 현재 비밀번호 입력
                      TextFormField(
                        controller: _currentPasswordController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)?.currentPassword ?? '현재 비밀번호',
                          hintText: AppLocalizations.of(context)?.currentPasswordHint ?? '현재 비밀번호를 입력하세요',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isCurrentPasswordVisible ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isCurrentPasswordVisible = !_isCurrentPasswordVisible;
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: !_isCurrentPasswordVisible,
                        textInputAction: TextInputAction.next,
                        validator: _validateCurrentPassword,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),

                      // 새 비밀번호 입력
                      TextFormField(
                        controller: _newPasswordController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)?.newPassword ?? '새 비밀번호',
                          hintText: AppLocalizations.of(context)?.newPasswordHint ?? '새 비밀번호를 입력하세요',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isNewPasswordVisible ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isNewPasswordVisible = !_isNewPasswordVisible;
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: !_isNewPasswordVisible,
                        textInputAction: TextInputAction.next,
                        validator: _validateNewPassword,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),

                      // 새 비밀번호 확인 입력
                      TextFormField(
                        controller: _confirmNewPasswordController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)?.confirmNewPassword ?? '새 비밀번호 확인',
                          hintText: AppLocalizations.of(context)?.confirmNewPasswordHint ?? '새 비밀번호를 다시 입력하세요',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmNewPasswordVisible ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmNewPasswordVisible = !_isConfirmNewPasswordVisible;
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: !_isConfirmNewPasswordVisible,
                        textInputAction: TextInputAction.done,
                        validator: _validateConfirmNewPassword,
                        enabled: !_isLoading,
                        onFieldSubmitted: (_) => _handleChangePassword(),
                      ),
                      const SizedBox(height: 32),

                      // 비밀번호 변경 버튼
                      FilledButton(
                        onPressed: _isLoading ? null : _handleChangePassword,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          AppLocalizations.of(context)?.changePassword ?? '비밀번호 변경',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
