# STT 개선 작업 - 2026-04-12 18:56

## 개요
- **시작 시간**: 2026-04-12 18:56 (KST)
- **작업 내용**: STT(Speech-to-Text) 기능 개선
- **현재 상태**: 구조 파악 완료, 개선 방향 논의 필요

## 목표
1. STT 관련 코드 구조 파악 및 이해
2. 개선할 부분 식별
3. 개선 방향 사용자와 논의
4. 구현 및 테스트

## 진행 상황

### 완료된 작업
- [x] STT 관련 파일 식별
  - `text_tab.dart`: STT UI 및 로직
  - `audio_service.dart`: 녹음 서비스 (STT와 병행)
  - `audio_file.dart`: 오디오 파일 모델
  - `recording_screen.dart`, `recording_tab.dart`: 녹음 UI
- [x] 이전 세션 문서 검토
  - 2026-03-14: STT 다국어 지원 시도 (번역 기능 실패로 롤백)
  - 2026-02-07: STT + 녹음 동시 사용 최적화 시도 (실패)
- [x] STT 현재 구현 분석

### STT 현재 구조 파악

#### 핵심 파일
1. **text_tab.dart** (L750-850)
   - `speech_to_text` 패키지 사용
   - 한국어로 하드코딩 (L790-796)
   - HTML 에디터와 연동
   - Wakelock으로 화면 잠금 방지
   - STT 중 키보드 비활성화

2. **audio_service.dart**
   - `record` 패키지로 녹음
   - `audioplayers` 패키지로 재생
   - RecordConfig: autoGain, echoCancel, noiseSuppress = true
   - AVAudioSessionMode.videoChat (마이크 공유)

3. **app_state_provider.dart**
   - `isSTTActive` 상태 관리
   - STT와 녹음 간 상태 공유

#### 이전 시도 내역
1. **다국어 지원** (2026-03-14)
   - ✅ STT 언어를 한국어 → 앱 설정 언어로 변경 시도
   - ✅ iOS Podfile 최소 버전 13.0 → 16.0 상향
   - ❌ 번역 기능 추가 시도 (google_mlkit_translation)
   - ❌ 실제 iPhone 크래시로 전체 롤백

2. **STT + 녹음 동시 사용** (2026-02-07)
   - ❌ 무음 파일 생성 문제
   - ❌ 텍스트 중복 및 꼬임 문제
   - ❌ STT 재시작 로직 부작용

#### 현재 확인된 이슈
1. **한국어 하드코딩** (L790-796)
   ```dart
   final koreanLocale = availableLocales.firstWhere(
     (l) => l.localeId.startsWith('ko'),
     orElse: () => availableLocales.first,
   );
   ```
   - 30개 언어 지원하는 앱이지만 STT는 한국어만 가능

2. **STT + 녹음 충돌**
   - 동시 사용 시 무음 파일 또는 텍스트 꼬임

3. **HTML 에디터 포커스 이슈**
   - STT 중 키보드 팝업 방지 로직 (복잡함)

### 대기 중인 작업
- [ ] 사용자와 개선 방향 논의
- [ ] 개선 계획 수립
- [ ] 구현
- [ ] 테스트

---

## 업데이트 - 2026-04-12 22:00

**요약**: STT 텍스트 입력 방식 개선 시도 - 실패 및 소스 원복

**Git 변경 사항**:
- 수정됨: .claude/sessions/.current-session
- 추가됨: .claude/sessions/2026-04-12-1853-iphone-test-verification.md
- 현재 브랜치: main (커밋: f888df2 홈화면 개선)
- 코드 변경: 모두 원복됨 (테스트 실패)

**할 일 진행 상황**: 완료 0건, 진행 중 0건, 실패 2건
- ✗ 실패: Search 모드 전환 (dictation → search)
- ✗ 실패: 바로 입력 방식 구현

**발생한 이슈**:

1. **STT 텍스트 중복 문제**
   - 증상: dictation 모드에서 발화한 내용이 중복되어 표시됨
   - 원인: STT가 이전 텍스트를 계속 재인식하면서 미세하게 변경 ("70 70 70" → "70 74 70")
   - `startsWith()` 체크가 실패하여 전체 누적 텍스트가 다시 표시됨

2. **사용자 요구사항**
   - "STT를 textfield에 발화했을 때 바로 넣지 않고 한꺼번에 넣는 이유가 뭐야?"
   - 기존: 회색 이탤릭 임시 span → 최종 확정 시 검은색 텍스트로 변환
   - 요구: 발화 즉시 검은색 텍스트로 바로 입력

**시도한 해결책**:

### 해결책 1: Search 모드 전환
- **변경 내용**:
  - `listenMode: stt.ListenMode.dictation` → `stt.ListenMode.search`
  - `pauseFor: 300초` → `3초`
  - 누적 텍스트 추적 로직 제거 (`_savedAccumulatedText`, `_lastFullText`)

- **결과**: 실패
  - STT 인식 품질 저하
  - 예상: "1 2 3 4..." → 실제: "쉬운", "만나지", "아쉬운" 등 무관한 단어 인식
  - 3초 침묵 후 최종 결과는 발생했으나 인식 내용이 부정확

### 해결책 2: 바로 입력 방식 구현
- **변경 내용** (`text_tab.dart`):
  1. 중간 결과 처리 로직 변경:
     - 기존: `_updatePartialSpan()` → 회색 임시 span 생성/업데이트
     - 변경: `_insertFinalText()` → 차분 계산 후 검은색 텍스트 즉시 삽입

  2. 차분 계산 로직:
     ```dart
     if (_lastPartialText.isEmpty) {
       _insertFinalText(currentText);  // 첫 입력: 전체 삽입
     } else if (currentText.startsWith(_lastPartialText)) {
       final diff = currentText.substring(_lastPartialText.length);
       if (diff.isNotEmpty) {
         _insertFinalText(diff);  // 차분만 삽입
       }
     } else {
       _insertFinalText(currentText);  // 완전히 다르면 전체 삽입
     }
     ```

  3. 제거된 함수들:
     - `_updatePartialSpan()` - 회색 임시 span 생성
     - `_convertPartialToFinal()` - 임시 span → 최종 텍스트 변환
     - `_removePartialSpan()` - 임시 span 제거
     - `_replaceFinalText()` - 임시 span → 텍스트 교체

- **결과**: 실패
  1. **JavaScript 에러 발생**:
     - 첫 입력 "하": `✅ 최종 텍스트 삽입: success`
     - 이후 모든 입력: `error: null is not an object (evaluating 't.node.nextSibling')`
     - 원인: Summernote 에디터의 커서 위치 관리 문제

  2. **텍스트 입력 실패**:
     - 1~50까지 발화했으나 "하" 하나만 입력됨
     - 나머지 입력은 모두 JavaScript 에러로 실패

  3. **차분 계산 불안정**:
     - "차분 추가"와 "전체 재입력"이 무작위로 섞임
     - STT가 이전 텍스트를 재인식하면서 `startsWith()` 체크 실패

**변경된 코드 내용**:
- 모든 변경사항 원복됨
- `text_tab.dart`: dictation 모드, 회색 임시 span 방식 유지

**근본 원인 분석**:

1. **dictation 모드의 특성**:
   - STT 엔진이 이전 텍스트를 계속 재인식하며 미세하게 변경
   - 문자열 기반 차분 계산(`startsWith()`)이 불가능
   - 누적 텍스트 추적 방식으로는 중복 방지 불가능

2. **Summernote 에디터 제약**:
   - `summernote.summernote('insertText')` 호출 시 내부 커서 관리
   - 연속적인 동적 텍스트 삽입 시 에러 발생
   - 첫 입력 후 커서 상태가 불안정해짐

**결론**:
- 기존의 **회색 임시 span 방식**이 가장 안정적
- 바로 입력 방식은 Summernote 에디터와 호환성 문제
- Search 모드는 STT 인식 품질 저하
- **세션 실패**: 소스 원복 완료

**다음 세션 권장 사항**:
1. 회색 임시 span의 스타일만 변경 (회색 → 검은색)
2. 또는 HTML 에디터를 Summernote에서 다른 에디터로 교체 검토
3. STT 중복 문제는 엔진 레벨의 제약으로 근본적 해결 어려움

---

## 세션 종료 - 2026-04-12 22:01 (KST)

### 세션 소요 시간
- **시작**: 2026-04-12 18:56 (KST)
- **종료**: 2026-04-12 22:01 (KST)
- **총 소요 시간**: 약 3시간 5분

### Git 요약
**변경된 전체 파일 수**: 2개
- 수정됨: 1개
- 추가됨: 1개
- 삭제됨: 0개

**변경된 파일 목록**:
1. `.claude/sessions/.current-session` (수정됨)
2. `.claude/sessions/2026-04-12-1853-iphone-test-verification.md` (추가됨)

**수행된 커밋**: 0개 (테스트 실패로 모든 변경사항 원복)

**최종 git 상태**:
- 현재 브랜치: main
- 마지막 커밋: f888df2 홈화면 개선
- 코드 변경: 없음 (소스 원복 완료)

### 할 일 요약
**완료된 작업**: 0개
**실패한 작업**: 2개
**남은 작업**: STT 개선 작업 전체

**실패한 작업 목록**:
1. ✗ Search 모드 전환 (dictation → search)
   - STT 인식 품질 저하로 실패

2. ✗ 바로 입력 방식 구현
   - Summernote 에디터 호환성 문제로 실패
   - JavaScript 에러 발생

**미완료 작업 목록**:
- [ ] STT 텍스트 중복 문제 해결
- [ ] STT 실시간 입력 개선
- [ ] 사용자 경험 향상

### 주요 성과
- **없음** (모든 시도 실패)

### 구현된 기능
- **없음** (소스 원복으로 코드 변경 없음)

### 발생한 문제와 해결 시도

#### 문제 1: STT 텍스트 중복 문제
**증상**:
- dictation 모드에서 발화한 내용이 중복되어 표시됨
- 예: "1~50" 발화 → "123-456-789 열 11 12..." 등이 중복 입력

**근본 원인**:
- STT 엔진이 이전 텍스트를 계속 재인식하면서 미세하게 변경
- "70 70 70" → "70 74 70"처럼 숫자가 바뀜
- `startsWith()` 체크가 실패하여 전체 누적 텍스트가 다시 표시됨

**시도한 해결책 1: Search 모드 전환**
```dart
// 변경 전
listenMode: stt.ListenMode.dictation
pauseFor: const Duration(seconds: 300)

// 변경 후
listenMode: stt.ListenMode.search
pauseFor: const Duration(seconds: 3)
```
- **결과**: 실패
- **이유**: STT 인식 품질이 크게 저하됨
- "1 2 3 4..." 대신 "쉬운", "만나지", "아쉬운" 등 무관한 단어 인식

**시도한 해결책 2: 누적 텍스트 추적**
```dart
String _lastFullText = '';
String _savedAccumulatedText = '';

// 차분 계산
if (_savedAccumulatedText.isNotEmpty &&
    currentText.startsWith(_savedAccumulatedText)) {
  newText = currentText.substring(_savedAccumulatedText.length);
}
```
- **결과**: 실패
- **이유**: STT 재인식으로 `startsWith()` 체크가 불안정

#### 문제 2: 사용자 요구사항 - 바로 입력
**요구사항**:
- "STT를 textfield에 발화했을 때 바로 넣지 않고 한꺼번에 넣는 이유가 뭐야?"
- 기존: 회색 이탤릭 임시 span → 최종 확정 시 검은색 변환
- 요구: 발화 즉시 검은색 텍스트로 바로 입력

**시도한 해결책: 차분 계산 후 즉시 삽입**
```dart
// 중간 결과 처리 변경
if (result.finalResult) {
  _insertFinalText(' ');  // 공백만 추가
} else {
  // 차분 계산
  if (_lastPartialText.isEmpty) {
    _insertFinalText(currentText);  // 첫 입력
  } else if (currentText.startsWith(_lastPartialText)) {
    final diff = currentText.substring(_lastPartialText.length);
    if (diff.isNotEmpty) {
      _insertFinalText(diff);  // 차분만 삽입
    }
  } else {
    _insertFinalText(currentText);  // 전체 재입력
  }
  _lastPartialText = currentText;
}
```

**제거된 함수들**:
- `_updatePartialSpan()` - 회색 임시 span 생성/업데이트
- `_convertPartialToFinal()` - 임시 span → 최종 텍스트 변환
- `_removePartialSpan()` - 임시 span 제거
- `_replaceFinalText()` - 임시 span → 텍스트 교체

**결과**: 실패

**발생한 에러**:
```
✅ 최종 텍스트 삽입: success  (첫 입력 "하"만 성공)
✅ 최종 텍스트 삽입: error: null is not an object (evaluating 't.node.nextSibling')  (이후 모든 입력 실패)
```

**실제 테스트 결과**:
- 1~50까지 발화했으나 "하" 하나만 텍스트 필드에 입력됨
- 나머지 입력은 모두 JavaScript 에러로 실패

**원인**:
1. Summernote 에디터의 커서 위치 관리 문제
2. 연속적인 `summernote.summernote('insertText')` 호출 시 내부 상태 충돌
3. 첫 입력 후 커서 상태가 불안정해짐

### 주요 변경 사항 및 발견

#### 발견 1: dictation 모드의 특성
- STT 엔진이 이전 텍스트를 계속 재인식하며 미세하게 변경
- 문자열 기반 차분 계산(`startsWith()`)이 불가능
- 누적 텍스트 추적 방식으로는 중복 방지 불가능
- **이는 엔진 레벨의 제약**으로 앱 레벨에서 해결 불가능

#### 발견 2: Summernote 에디터 제약
- `summernote.summernote('insertText')` 연속 호출 시 에러 발생
- 동적 텍스트 삽입에 적합하지 않음
- 임시 span 방식이 더 안정적

#### 발견 3: Search vs Dictation 모드
- **Search 모드**:
  - 장점: 2-3초 침묵 시 자동 구분, `isFinal: true` 정기적 발생
  - 단점: 인식 품질 저하, 짧은 발화에 최적화

- **Dictation 모드**:
  - 장점: 긴 발화 인식에 최적화, 높은 인식 품질
  - 단점: `isFinal: true` 거의 발생 안 함, 누적 텍스트 관리 필요

### 추가/제거된 종속성
- **없음**

### 설정 변경 사항
- **없음** (모든 변경사항 원복)

### 수행된 배포 단계
1. Flutter clean 실행
2. iOS 릴리즈 빌드 (여러 차례)
3. iPhone 실제 기기 테스트 (여러 차례)
4. 모든 변경사항 원복

### 얻은 교훈

#### 1. STT 엔진의 동작 방식 이해
- dictation 모드는 이전 텍스트를 계속 재인식함
- 문자열 기반 비교로 차분 계산이 불가능
- 엔진 레벨의 제약은 앱에서 해결할 수 없음

#### 2. HTML 에디터의 제약 이해
- Summernote는 동적 텍스트 삽입에 적합하지 않음
- JavaScript 커서 관리가 복잡하고 불안정
- 임시 DOM 요소(span) 방식이 더 안정적

#### 3. 사용자 요구사항과 기술적 제약의 균형
- "바로 입력"이라는 요구사항은 합리적이나
- 현재 기술 스택(Summernote + dictation)으로는 구현 불가능
- 대안 제시 필요: 스타일 변경 또는 에디터 교체

#### 4. 테스트의 중요성
- 실제 기기 테스트 없이는 문제 발견 불가능
- JavaScript 에러는 로그를 통해서만 확인 가능
- 반복적인 빌드와 테스트가 필수

### 완료되지 않은 작업

#### 즉시 필요한 작업
1. **STT 중복 문제 해결**
   - 상태: 미해결
   - 이유: dictation 모드의 엔진 레벨 제약
   - 권장: 사용자에게 현재 동작 방식 설명 및 수용 요청

2. **사용자 경험 개선**
   - 상태: 미해결
   - 대안 1: 회색 임시 span의 색상을 검은색으로 변경
   - 대안 2: HTML 에디터를 Summernote에서 다른 에디터로 교체

#### 장기 과제
1. **HTML 에디터 교체 검토**
   - 현재: Summernote (jQuery 기반, 2017년 이후 업데이트 중단)
   - 고려 대상: Quill, TinyMCE, 또는 Flutter 네이티브 에디터
   - 장점: 더 나은 프로그래밍 제어, 최신 기술

2. **STT 다국어 지원**
   - 현재: 한국어만 지원
   - 목표: 30개 언어 지원
   - 과거 시도: 실패 (2026-03-14 iPhone 크래시)

### 미래 개발자를 위한 팁

#### STT 관련
1. **dictation 모드 사용 시**:
   - 이전 텍스트 재인식은 정상 동작임
   - 문자열 기반 중복 제거는 불가능
   - 임시 span 방식 권장

2. **search 모드 사용 시**:
   - 짧은 발화에 적합
   - 인식 품질이 dictation보다 낮을 수 있음
   - `pauseFor` 시간을 신중히 설정

3. **STT 디버깅**:
   - 반드시 실제 기기에서 테스트
   - 로그에서 `isFinal`, `recognizedWords` 확인
   - 중간 결과와 최종 결과의 차이 이해

#### Summernote 에디터 관련
1. **동적 텍스트 삽입**:
   - `summernote('insertText')` 연속 호출 지양
   - DOM 직접 조작 (span 삽입) 권장
   - 커서 위치 관리에 주의

2. **대안 검토**:
   - Summernote는 유지보수 중단됨
   - 새 프로젝트라면 다른 에디터 검토
   - Flutter 네이티브 에디터도 고려

#### 테스트 관련
1. **실제 기기 테스트 필수**:
   - iOS Simulator에서는 STT 테스트 불가능
   - JavaScript 에러는 로그로만 확인 가능
   - 빌드 시간이 길어도 실제 기기 테스트 필수

2. **로그 모니터링**:
   - `tail -f` 로 실시간 로그 확인
   - 특정 패턴 grep으로 필터링
   - debugPrint를 적극 활용

### 결론
이번 세션은 **실패**했지만, STT와 HTML 에디터의 제약사항을 명확히 이해하게 되었습니다.

**핵심 발견**:
- dictation 모드의 텍스트 재인식은 엔진 레벨의 특성
- Summernote 에디터는 동적 텍스트 삽입에 부적합
- 현재 기술 스택으로는 "바로 입력" 불가능

**다음 세션 권장 방향**:
1. 회색 임시 span의 스타일만 변경 (가장 간단한 해결책)
2. 또는 근본적으로 HTML 에디터 교체 검토 (장기 과제)

**세션 종료**: 2026-04-12 22:01 (KST)
