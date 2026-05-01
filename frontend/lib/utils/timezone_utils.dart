import 'package:timezone/timezone.dart' as tz;

/// 언어 코드 → 대표 타임존 매핑
/// 앱이 지원하는 30개 언어 기준
const Map<String, String> _languageToTimezone = {
  'ko': 'Asia/Seoul',          // 한국어
  'ja': 'Asia/Tokyo',          // 일본어
  'zh': 'Asia/Shanghai',       // 중국어
  'en': 'America/New_York',    // 영어 (미국)
  'es': 'America/Mexico_City', // 스페인어
  'fr': 'Europe/Paris',        // 프랑스어
  'de': 'Europe/Berlin',       // 독일어
  'it': 'Europe/Rome',         // 이탈리아어
  'pt': 'America/Sao_Paulo',   // 포르투갈어
  'ru': 'Europe/Moscow',       // 러시아어
  'ar': 'Asia/Riyadh',         // 아랍어
  'hi': 'Asia/Kolkata',        // 힌디어
  'bn': 'Asia/Dhaka',          // 벵골어
  'ur': 'Asia/Karachi',        // 우르두어
  'id': 'Asia/Jakarta',        // 인도네시아어
  'ms': 'Asia/Kuala_Lumpur',   // 말레이어
  'tr': 'Europe/Istanbul',     // 터키어
  'uk': 'Europe/Kiev',         // 우크라이나어
  'pl': 'Europe/Warsaw',       // 폴란드어
  'ro': 'Europe/Bucharest',    // 루마니아어
  'nl': 'Europe/Amsterdam',    // 네덜란드어
  'fa': 'Asia/Tehran',         // 페르시아어
  'ps': 'Asia/Kabul',          // 파슈토어
  'mr': 'Asia/Kolkata',        // 마라티어
  'te': 'Asia/Kolkata',        // 텔루구어
  'ta': 'Asia/Kolkata',        // 타밀어
  'sw': 'Africa/Nairobi',      // 스와힐리어
  'ha': 'Africa/Lagos',        // 하우사어
  'tl': 'Asia/Manila',         // 타갈로그어
  'th': 'Asia/Bangkok',        // 태국어
};

/// 언어 코드에 해당하는 타임존 위치를 반환
/// 매핑이 없으면 UTC 반환
tz.Location getTimezoneForLanguage(String languageCode) {
  final tzName = _languageToTimezone[languageCode] ?? 'UTC';
  try {
    return tz.getLocation(tzName);
  } catch (_) {
    return tz.UTC;
  }
}

/// 언어 코드 기준 현재 시각 (TZDateTime)
tz.TZDateTime nowForLanguage(String languageCode) {
  return tz.TZDateTime.now(getTimezoneForLanguage(languageCode));
}
