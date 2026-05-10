import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

const _kLanguages = [
  ('ko', '한국어'),
  ('en', 'English'),
  ('zh', '中文'),
  ('ja', '日本語'),
  ('hi', 'हिन्दी'),
  ('es', 'Español'),
  ('fr', 'Français'),
  ('ar', 'العربية'),
  ('bn', 'বাংলা'),
  ('ru', 'Русский'),
  ('pt', 'Português'),
  ('ur', 'اردو'),
  ('id', 'Bahasa Indonesia'),
  ('de', 'Deutsch'),
  ('sw', 'Kiswahili'),
  ('mr', 'मराठी'),
  ('te', 'తెలుగు'),
  ('tr', 'Türkçe'),
  ('ta', 'தமிழ்'),
  ('fa', 'فارسی'),
  ('uk', 'Українська'),
  ('it', 'Italiano'),
  ('tl', 'Filipino'),
  ('pl', 'Polski'),
  ('ps', 'پښتو'),
  ('ms', 'Bahasa Melayu'),
  ('ro', 'Română'),
  ('nl', 'Nederlands'),
  ('ha', 'Hausa'),
  ('th', 'ไทย'),
];

class SttMemoSettings {
  final String textLanguage;
  final String summaryLanguage;
  final int summaryLevel;
  final int summaryIntervalMinutes; // -1 = 종료 시, 0 = 안함

  const SttMemoSettings({
    this.textLanguage = 'ko',
    this.summaryLanguage = 'ko',
    this.summaryLevel = 3,
    this.summaryIntervalMinutes = -1,
  });

  Duration? get summaryInterval =>
      summaryIntervalMinutes > 0 ? Duration(minutes: summaryIntervalMinutes) : null;
}

class SttMemoSettingsDialog extends StatefulWidget {
  const SttMemoSettingsDialog({super.key});

  @override
  State<SttMemoSettingsDialog> createState() => _SttMemoSettingsDialogState();
}

class _SttMemoSettingsDialogState extends State<SttMemoSettingsDialog> {
  String _textLanguage = 'ko';
  String _summaryLanguage = 'ko';
  int _summaryLevel = 3;
  int _summaryIntervalMinutes = -1;

  String _levelDescription(AppLocalizations? l10n) => switch (_summaryLevel) {
    1 => l10n?.summaryLevelDesc1 ?? '핵심 주제와 결론만 · 약 10%',
    2 => l10n?.summaryLevelDesc2 ?? '주요 기능과 핵심 논의 · 약 25%',
    3 => l10n?.summaryLevelDesc3 ?? '실무 흐름과 설계 의도 · 약 40~50%',
    4 => l10n?.summaryLevelDesc4 ?? '전체 논의 흐름 대부분 · 약 70%',
    5 => l10n?.summaryLevelDesc5 ?? '전체 맥락 최대한 유지 · 약 90%',
    _ => l10n?.summaryLevelDesc3 ?? '실무 흐름과 설계 의도 · 약 40~50%',
  };

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context);

    final intervalOptions = [
      (3,  l10n?.intervalMin(3)  ?? '3분'),
      (5,  l10n?.intervalMin(5)  ?? '5분'),
      (10, l10n?.intervalMin(10) ?? '10분'),
      (30, l10n?.intervalMin(30) ?? '30분'),
      (-1, l10n?.intervalOnStop  ?? '종료'),
      (0,  l10n?.intervalOff     ?? '안함'),
    ];

    final summaryLevelItems = [
      (1, l10n?.summaryLevelOneLiner  ?? '한줄 요약'),
      (2, l10n?.summaryLevelBrief     ?? '간단 요약'),
      (3, l10n?.summaryLevelNormal    ?? '일반 요약'),
      (4, l10n?.summaryLevelDetailed  ?? '상세 요약'),
      (5, l10n?.summaryLevelFull      ?? '거의 전체'),
    ];

    return AlertDialog(
      title: Row(children: [
        Icon(Icons.record_voice_over, color: color, size: 20),
        const SizedBox(width: 8),
        Text(l10n?.voiceMemoSettings ?? '음성 메모 설정', style: const TextStyle(fontSize: 15)),
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 전사 언어
              _buildLabel(l10n?.transcriptionLanguage ?? '전사 언어', color),
              const SizedBox(height: 6),
              _buildDropdown(
                value: _textLanguage,
                onChanged: (v) => setState(() => _textLanguage = v!),
                color: color,
              ),
              const SizedBox(height: 14),

              // 요약 언어
              _buildLabel(l10n?.summaryLanguage ?? '요약 언어', color),
              const SizedBox(height: 6),
              _buildDropdown(
                value: _summaryLanguage,
                onChanged: (v) => setState(() => _summaryLanguage = v!),
                color: color,
              ),
              const SizedBox(height: 14),

              // 요약 수준
              _buildLabel(l10n?.summaryLevel ?? '요약 수준', color),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: _summaryLevel,
                isDense: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: color),
                  ),
                ),
                items: summaryLevelItems
                    .map((lv) => DropdownMenuItem<int>(
                          value: lv.$1,
                          child: Text('${lv.$1}. ${lv.$2}', style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _summaryLevel = v!),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _levelDescription(l10n),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 14),

              // 자동 요약 주기
              _buildLabel(l10n?.autoSummaryInterval ?? '자동 요약 주기', color),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: intervalOptions.map((opt) {
                  final selected = _summaryIntervalMinutes == opt.$1;
                  return ChoiceChip(
                    label: Text(opt.$2,
                        style: TextStyle(
                          fontSize: 12,
                          color: selected ? Colors.white : color,
                          fontWeight: FontWeight.w500,
                        )),
                    selected: selected,
                    selectedColor: color,
                    backgroundColor: color.withValues(alpha: 0.08),
                    side: BorderSide(color: color.withValues(alpha: 0.3)),
                    onSelected: (_) => setState(() => _summaryIntervalMinutes = opt.$1),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n?.cancel ?? '취소'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(
            context,
            SttMemoSettings(
              textLanguage: _textLanguage,
              summaryLanguage: _summaryLanguage,
              summaryLevel: _summaryLevel,
              summaryIntervalMinutes: _summaryIntervalMinutes,
            ),
          ),
          icon: const Icon(Icons.mic, size: 16),
          label: Text(l10n?.startButton ?? '시작'),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Text(text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700));
  }

  Widget _buildDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
    required Color color,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isDense: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color),
        ),
      ),
      items: _kLanguages.map((lang) {
        return DropdownMenuItem<String>(
          value: lang.$1,
          child: Text('${lang.$2}  (${lang.$1})', style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
