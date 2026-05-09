import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/text_file.dart';

// 앱 지원 30개 언어 목록 (code → 표시명)
const _kLevels = [
  (1, '한줄 요약'),
  (2, '간단 요약'),
  (3, '일반 요약'),
  (4, '상세 요약'),
  (5, '거의 전체'),
];

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

const _kLevelNames = {1: '한줄', 2: '간단', 3: '일반', 4: '상세', 5: '전체'};

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

  // 이력 선택 (null = 이력 없음 또는 미선택)
  SummaryRecord? _selectedHistory;

  @override
  void initState() {
    super.initState();
    // 가장 최근 이력이 있으면 기본 선택
    if (widget.file.summaryHistory.isNotEmpty) {
      _selectedHistory = widget.file.summaryHistory.first;
    }
  }

  String get _levelDescription => switch (_summaryLevel) {
    1 => '핵심 주제와 결론만 · 약 10% · 임원/리더 빠른 확인용',
    2 => '주요 기능과 핵심 논의 · 약 25% · 팀 공유용',
    3 => '실무 흐름과 설계 의도 · 약 40~50% · 일반 회의록 공유',
    4 => '전체 논의 흐름 대부분 · 약 70% · 상세 실무 검토용',
    5 => '전체 맥락 최대한 유지 · 약 90% · 회의 복기 및 문서화',
    _ => '실무 흐름과 설계 의도 · 약 40~50% · 일반 회의록 공유',
  };

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final history = widget.file.summaryHistory;

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
                _buildLabel('요약 이력'),
                const SizedBox(height: 6),
                _buildHistoryDropdown(history, color),
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
                  SizedBox(width: 80, child: _buildLabel('대상 언어')),
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
                  SizedBox(width: 80, child: _buildLabel('요약 언어')),
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
                  SizedBox(width: 80, child: _buildLabel('요약 수준')),
                  Expanded(
                    child: _buildLevelDropdown(),
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
                  _levelDescription,
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
                      Text('AI가 요약 중입니다...',
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
          child: const Text('닫기'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _onSummarize,
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: Text(history.isNotEmpty ? '다시 요약' : '요약하기'),
        ),
      ],
    );
  }

  Widget _buildHistoryDropdown(List<SummaryRecord> history, Color color) {
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
        final levelName = _kLevelNames[rec.level] ?? '일반';
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
    // ⭐ 리마인드 섹션 제거 (본문 요약만 표시)
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

  Widget _buildLevelDropdown() {
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
      items: _kLevels.map((lv) {
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
    // 정규식: 모든 SUMMARY_START ~ SUMMARY_END 쌍을 제거 (multiline, dotall)
    final regex = RegExp(
      r'<!--\s*SUMMARY_START\s*-->.*?<!--\s*SUMMARY_END\s*-->',
      multiLine: true,
      dotAll: true,
    );
    String cleaned = content.replaceAll(regex, '');

    // SUMMARY_START 마커만 있고 END가 없는 경우(비정상 종료) — START 이후 모두 제거
    final orphanStart = cleaned.indexOf('<!-- SUMMARY_START -->');
    if (orphanStart != -1) {
      cleaned = cleaned.substring(0, orphanStart);
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
      // ⭐ 이전에 삽입된 자동 요약 블록을 모두 제거하고 순수 전사 내용만 전송
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
