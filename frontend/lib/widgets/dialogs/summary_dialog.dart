import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/text_file.dart';

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
  int _summaryRatio = 50;
  bool _isLoading = false;
  String? _errorMessage;

  String get _ratioLabel {
    if (_summaryRatio <= 20) return '매우 간략';
    if (_summaryRatio <= 40) return '간략';
    if (_summaryRatio <= 60) return '보통';
    if (_summaryRatio <= 80) return '상세';
    return '매우 상세';
  }

  int get _pointCount => _summaryRatio ~/ 10;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;

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
              // 기존 요약 표시
              if (widget.file.hasSummary) ...[
                Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.auto_awesome, size: 13, color: color),
                        const SizedBox(width: 4),
                        Text('기존 요약',
                            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 6),
                      Text(widget.file.summary!,
                          style: const TextStyle(fontSize: 12, height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('다시 요약', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 12),
              ],

              // 텍스트 언어
              _buildLabel('텍스트 언어'),
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
                    '$_ratioLabel · $_pointCount개 포인트',
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
                  ),
                ),
              ),

              // 에러 메시지
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

              // 로딩
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
          label: Text(widget.file.hasSummary ? '다시 요약' : '요약하기'),
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
          child: Text('${lang.$2}  (${lang.$1})',
              style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _onSummarize() async {
    debugPrint('✨ [SummaryDialog] 요약 시작 - textLang: $_textLanguage, summaryLang: $_summaryLanguage, ratio: $_summaryRatio');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ApiService();
      final summary = await apiService.summarizeText(
        text: widget.file.content,
        textLanguage: _textLanguage,
        summaryLanguage: _summaryLanguage,
        summaryRatio: _summaryRatio,
        fileId: widget.file.id,
      );

      debugPrint('✨ [SummaryDialog] 요약 완료 - 길이: ${summary.length}');

      if (mounted) {
        Navigator.pop(context, SummaryResult(
          summary: summary,
          textLanguage: _textLanguage,
          summaryLanguage: _summaryLanguage,
          summaryRatio: _summaryRatio,
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
  final int summaryRatio;

  const SummaryResult({
    required this.summary,
    required this.textLanguage,
    required this.summaryLanguage,
    required this.summaryRatio,
  });
}
