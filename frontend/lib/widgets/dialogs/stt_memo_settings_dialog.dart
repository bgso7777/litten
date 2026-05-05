import 'package:flutter/material.dart';

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

// 요약 주기 옵션
const _kIntervalOptions = [
  (1, '1분'),
  (3, '3분'),
  (5, '5분'),
  (10, '10분'),
  (0, '안함'),
];

class SttMemoSettings {
  final String textLanguage;
  final String summaryLanguage;
  final int summaryRatio;
  final int summaryIntervalMinutes; // 0 = 안함

  const SttMemoSettings({
    this.textLanguage = 'ko',
    this.summaryLanguage = 'ko',
    this.summaryRatio = 10,
    this.summaryIntervalMinutes = 3,
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
  int _summaryRatio = 10;
  int _summaryIntervalMinutes = 3;

  String get _ratioLabel {
    return switch (_summaryRatio) {
      10 => '핵심만',
      20 => '핵심 흐름',
      30 => '전개 흐름',
      40 => '전체 흐름',
      50 => '흐름+내용',
      60 => '전개 과정',
      70 => '전체+결론',
      80 => '세부+Q&A',
      90 => '완전 상세',
      _ => '흐름+내용',
    };
  }

  String get _ratioDescription {
    return switch (_summaryRatio) {
      10 => '가장 핵심적인 주제만',
      20 => '주요 주제 간략하게',
      30 => '주요 주제 요약',
      40 => '주제+세부 내용',
      50 => '주제+내용+의견',
      60 => '주제+논의 과정',
      70 => '모든 주제+논의',
      80 => '모든 내용 상세',
      90 => '거의 모든 내용',
      _ => '주제+내용+의견',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;

    return AlertDialog(
      title: Row(children: [
        Icon(Icons.record_voice_over, color: color, size: 20),
        const SizedBox(width: 8),
        const Text('음성 메모 설정', style: TextStyle(fontSize: 15)),
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 언어
              _buildLabel('전사 언어'),
              const SizedBox(height: 6),
              _buildDropdown(
                value: _textLanguage,
                onChanged: (v) => setState(() => _textLanguage = v!),
              ),
              const SizedBox(height: 14),

              // 요약 언어
              _buildLabel('요약 언어'),
              const SizedBox(height: 6),
              _buildDropdown(
                value: _summaryLanguage,
                onChanged: (v) => setState(() => _summaryLanguage = v!),
              ),
              const SizedBox(height: 14),

              // 요약 비율
              _buildLabel('요약 비율'),
              const SizedBox(height: 4),
              Row(children: [
                Text('간략', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                Expanded(
                  child: Slider(
                    value: _summaryRatio.toDouble(),
                    min: 10,
                    max: 90,
                    divisions: 8,
                    activeColor: color,
                    label: '$_summaryRatio%',
                    onChanged: (v) => setState(() => _summaryRatio = v.round()),
                  ),
                ),
                Text('상세', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ]),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_ratioLabel · $_ratioDescription',
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 요약 주기
              _buildLabel('자동 요약 주기'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _kIntervalOptions.map((opt) {
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
          child: const Text('취소'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(
            context,
            SttMemoSettings(
              textLanguage: _textLanguage,
              summaryLanguage: _summaryLanguage,
              summaryRatio: _summaryRatio,
              summaryIntervalMinutes: _summaryIntervalMinutes,
            ),
          ),
          icon: const Icon(Icons.mic, size: 16),
          label: const Text('시작'),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700));
  }

  Widget _buildDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    final color = Theme.of(context).primaryColor;
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
