import '../models/remind_item.dart';

/// AI 요약 텍스트에서 "─── 📌 리마인드 ───" 섹션을 파싱해 RemindItem 목록으로 변환
class RemindParser {
  static const _sectionMarker = '─── 📌 리마인드 ───';

  static List<RemindItem> parse({
    required String summaryText,
    required String fileId,
    required String fileName,
    required String littenId,
    RemindFileType fileType = RemindFileType.text,
  }) {
    final startIdx = summaryText.indexOf(_sectionMarker);
    if (startIdx == -1) {
      return [];
    }

    final section = summaryText.substring(startIdx + _sectionMarker.length);
    final lines = section.split('\n');

    final items = <RemindItem>[];
    String currentGroup = '';
    String? pendingTitle;
    final detailBuf = StringBuffer();

    void flush() {
      if (pendingTitle == null) return;
      final title = currentGroup.isNotEmpty
          ? '[$currentGroup] $pendingTitle'
          : pendingTitle!;
      items.add(RemindItem(
        fileId: fileId,
        fileType: fileType,
        fileName: fileName,
        littenId: littenId,
        title: title,
        content: detailBuf.toString().trim(),
      ));
      pendingTitle = null;
      detailBuf.clear();
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('리마인드 총') || line.startsWith('없음')) break;

      if (line.startsWith('📂')) {
        flush();
        currentGroup = line.replaceFirst('📂', '').trim();
      } else if (line.startsWith('▸')) {
        flush();
        pendingTitle = line.replaceFirst('▸', '').trim();
      } else if (line.startsWith('└')) {
        final detail = line.replaceFirst('└', '').trim();
        if (detailBuf.isNotEmpty) detailBuf.write('\n');
        detailBuf.write(detail);
      }
    }
    flush();

    return items;
  }
}
