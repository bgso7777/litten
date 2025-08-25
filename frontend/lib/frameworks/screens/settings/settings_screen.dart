import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../providers/theme_provider.dart';
import '../../providers/locale_provider.dart';

/// 설정 화면
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 테마 설정 카드
        _buildThemeSettingsCard(context, l10n),
        const SizedBox(height: 16),
        
        // 언어 설정 카드
        _buildLanguageSettingsCard(context, l10n),
        const SizedBox(height: 16),
        
        // 앱 정보 카드
        _buildAppInfoCard(context, l10n),
      ],
    );
  }

  /// 테마 설정 카드
  Widget _buildThemeSettingsCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.theme,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return ListTile(
                  leading: const Icon(Icons.palette),
                  title: Text('현재 테마'),
                  subtitle: Text(themeProvider.currentThemeName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThemeSelector(context, themeProvider),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 언어 설정 카드
  Widget _buildLanguageSettingsCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.language,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Consumer<LocaleProvider>(
              builder: (context, localeProvider, child) {
                return ListTile(
                  leading: const Icon(Icons.language),
                  title: Text('현재 언어'),
                  subtitle: Text(localeProvider.currentLanguageName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLanguageSelector(context, localeProvider),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 앱 정보 카드
  Widget _buildAppInfoCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '앱 정보',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('버전'),
              subtitle: const Text('1.0.0'),
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('개발자'),
              subtitle: const Text('Litten Team'),
            ),
          ],
        ),
      ),
    );
  }

  /// 테마 선택 다이얼로그
  void _showThemeSelector(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('테마 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: themeProvider.availableThemes.entries.map((entry) {
            final themeKey = entry.key;
            final themeName = entry.value;
            final isSelected = themeProvider.currentTheme == themeKey;
            
            return RadioListTile<String>(
              title: Text(themeName),
              value: themeKey,
              groupValue: themeProvider.currentTheme,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setTheme(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  /// 언어 선택 다이얼로그
  void _showLanguageSelector(BuildContext context, LocaleProvider localeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('언어 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: localeProvider.allSupportedLanguages.length,
            itemBuilder: (context, index) {
              final langInfo = localeProvider.allSupportedLanguages[index];
              final languageCode = langInfo['code'] as String;
              final languageName = langInfo['name'] as String;
              final isSelected = localeProvider.languageCode == languageCode;
              
              return RadioListTile<String>(
                title: Text(languageName),
                value: languageCode,
                groupValue: localeProvider.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    localeProvider.setLocale(Locale(value));
                    Navigator.of(context).pop();
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
}