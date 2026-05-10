import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/text_file.dart';
import '../../l10n/app_localizations.dart';

// 앱 지원 30개 언어 목록 (code → 표시명)
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

class SummaryDialog extends StatefulWidget {
  final TextFile file;

  const SummaryDialog({super.key, required this.file});

  @override
  State<SummaryDialog> createState() => _SummaryDialogState();
}

class _SummaryDialogState extends State<SummaryDialog> {
  String _textLanguage = 'ko';
  String _summaryLanguage = 'ko';
  int _summaryLevel = 3;
  bool _isLoading = false;
  String? _errorMessage;

  SummaryRecord? _selectedHistory;

  @override
  void initState() {
    super.initState();
    if (widget.file.summaryHistory.isNotEmpty) {
      _selectedHistory = widget.file.summaryHistory.first;
    }
  }

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
    final history = widget.file.summaryHistory;

    final levelItems = [
      (1, l10n?.summaryLevelOneLiner  ?? '한줄 요약'),
      (2, l10n?.summaryLevelBrief     ?? '간단 요약'),
      (3, l10n?.summaryLevelNormal    ?? '일반 요약'),
      (4, l10n?.summaryLevelDetailed  ?? '상세 요약'),
      (5, l10n?.summaryLevelFull      ?? '거의 전체'),
    ];

    final levelShortNames = {
      1: l10n?.summaryLevelShortOneLiner  ?? '한줄',
      2: l10n?.summaryLevelShortBrief     ?? '간단',
      3: l10n?.summaryLevelShortNormal    ?? '일반',
      4: l10n?.summaryLevelShortDetailed  ?? '상세',
      5: l10n?.summaryLevelShortFull      ?? '전체',
    };

    return AlertDialog(
      title: Row(children: [
        Icon(Icons.auto_awesome, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.file.displayTitle,
            style: const TextStyle(fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 요약 이력 ──────────────────────────────
              if (history.isNotEmpty) ...[
                _buildLabel(l10n?.summaryHistory ?? '요약 이력'),
                const SizedBox(height: 6),
                _buildHistoryDropdown(history, color, levelShortNames),
                const SizedBox(height: 8),
                if (_selectedHistory != null)
                  _buildHistorySummaryBox(_selectedHistory!, color),
                const SizedBox(height: 16),
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: 12),
              ],

              // ── 대상 언어 (라벨 + 드롭다운 한 라인) ─────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 80, child: _buildLabel(l10n?.targetLanguage ?? '대상 언어')),
                  Expanded(
                    child: _buildDropdown(
                      value: _textLanguage,
                      onChanged: (v) => setState(() => _textLanguage = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── 요약 언어 (라벨 + 드롭다운 한 라인) ─────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 80, child: _buildLabel(l10n?.summaryLanguage ?? '요약 언어')),
                  Expanded(
                    child: _buildDropdown(
                      value: _summaryLanguage,
                      onChanged: (v) => setState(() => _summaryLanguage = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ── 요약 수준 (라벨 + 드롭다운 한 라인) ─────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 80, child: _buildLabel(l10n?.summaryLevel ?? '요약 수준')),
                  Expanded(
                    child: _buildLevelDropdown(levelItems),
                  ),
                ],
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
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.5),
                ),
              ),

              // ── 에러 ──────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(_errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ],

              // ── 로딩 ──────────────────────────────────
              if (_isLoading) ...[
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: color, strokeWidth: 2),
                      const SizedBox(height: 8),
                      Text(l10n?.aiSummarizing ?? 'AI가 요약 중입니다...',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(l10n?.close ?? '닫기'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _onSummarize,
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: Text(history.isNotEmpty
              ? (l10n?.summarizeAgain ?? '다시 요약')
              : (l10n?.summarize ?? '요약하기')),
        ),
      ],
    );
  }

  Widget _buildHistoryDropdown(
      List<SummaryRecord> history, Color color, Map<int, String> levelShortNames) {
    return DropdownButtonFormField<SummaryRecord>(
      value: _selectedHistory,
      isDense: true,
      isExpanded: true,
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
      items: history.map((rec) {
        final levelName = levelShortNames[rec.level] ?? '일반';
        return DropdownMenuItem<SummaryRecord>(
          value: rec,
          child: Text(
            '${rec.label}  Lv.${ rec.level} $levelName',
            style: const TextStyle(fontSize: 13),
          ),
        );
      }).toList(),
      onChanged: (v) => setState(() => _selectedHistory = v),
    );
  }

  Widget _buildHistorySummaryBox(SummaryRecord rec, Color color) {
    const reminderMarker = '─── 📌 리마인드 ───';
    final reminderIdx = rec.summary.indexOf(reminderMarker);
    final summaryOnly = reminderIdx != -1
        ? rec.summary.substring(0, reminderIdx).trim()
        : rec.summary;

    return Container(
      width: double.maxFinite,
      constraints: const BoxConstraints(maxHeight: 240),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: SingleChildScrollView(
        child: SelectableText.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '📅 ${rec.label}\n\n',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              TextSpan(
                text: summaryOnly,
                style: const TextStyle(fontSize: 12, height: 1.5, color: Colors.black),
              ),
            ],
          ),
        ),
      ),
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
      isExpanded: true,
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
          child: Text('${lang.$2}  (${lang.$1})',
              style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildLevelDropdown(List<(int, String)> levelItems) {
    final color = Theme.of(context).primaryColor;
    return DropdownButtonFormField<int>(
      value: _summaryLevel,
      isDense: true,
      isExpanded: true,
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
      items: levelItems.map((lv) {
        return DropdownMenuItem<int>(
          value: lv.$1,
          child: Text('${lv.$1}. ${lv.$2}', style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
      onChanged: (v) => setState(() => _summaryLevel = v!),
    );
  }

  /// 자동 요약 마커(<!-- SUMMARY_START --> ... <!-- SUMMARY_END -->) 사이의
  /// 모든 요약 블록을 제거하고 순수한 전사/입력 내용만 반환
  String _stripAutoSummaryBlocks(String content) {
    final regex = RegExp(
      r'<!--\s*SUMMARY_START\s*-->.*?<!--\s*SUMMARY_END\s*-->',
      multiLine: true,
      dotAll: true,
    );
    String cleaned = content.replaceAll(regex, '');

    final orphanStart = cleaned.indexOf('<!-- SUMMARY_START -->');
    if (orphanStart != -1) {
      cleaned = cleaned.substring(0, orphanStart);
    }

    final hrSummaryPattern = RegExp(
      r'<hr\s*/?>\s*<p[^>]*>\s*<strong[^>]*>📋\s*AI\s*요약</strong>',
      dotAll: true,
    );
    final hrMatch = hrSummaryPattern.firstMatch(cleaned);
    if (hrMatch != null) {
      debugPrint('✨ [SummaryDialog] <hr>+📋AI요약 패턴 발견 - 이후 제거 (offset: ${hrMatch.start})');
      cleaned = cleaned.substring(0, hrMatch.start);
    }

    final aiIdx = cleaned.indexOf('[AI 요약]');
    if (aiIdx != -1) {
      final beforeAi = cleaned.substring(0, aiIdx);
      final lastTagStart = beforeAi.lastIndexOf('<');
      final cutPoint = lastTagStart != -1 ? lastTagStart : aiIdx;
      debugPrint('✨ [SummaryDialog] [AI 요약] 텍스트 발견 - 이후 제거 (offset: $cutPoint)');
      cleaned = cleaned.substring(0, cutPoint);
    }

    return cleaned;
  }

  Future<void> _onSummarize() async {
    debugPrint('✨ [SummaryDialog] 요약 시작 - textLang: $_textLanguage, summaryLang: $_summaryLanguage, level: $_summaryLevel');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pureContent = _stripAutoSummaryBlocks(widget.file.content);
      debugPrint('✨ [SummaryDialog] 원본 길이: ${widget.file.content.length}, 요약 제거 후: ${pureContent.length}');

      final apiService = ApiService();
      final summary = await apiService.summarizeText(
        text: pureContent,
        textLanguage: _textLanguage,
        summaryLanguage: _summaryLanguage,
        summaryLevel: _summaryLevel,
        fileId: widget.file.id,
      );

      debugPrint('✨ [SummaryDialog] 요약 완료 - 길이: ${summary.length}');

      if (mounted) {
        Navigator.pop(context, SummaryResult(
          summary: summary,
          textLanguage: _textLanguage,
          summaryLanguage: _summaryLanguage,
          summaryLevel: _summaryLevel,
        ));
      }
    } catch (e) {
      debugPrint('❌ [SummaryDialog] 요약 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }
}

class SummaryResult {
  final String summary;
  final String textLanguage;
  final String summaryLanguage;
  final int summaryLevel;

  const SummaryResult({
    required this.summary,
    required this.textLanguage,
    required this.summaryLanguage,
    required this.summaryLevel,
  });
}
