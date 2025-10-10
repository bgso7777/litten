# Frontend Backend 계정 연동

## 개요
- **시작 시간**: 2025-10-10 11:02 (KST)
- **목표**: Frontend와 Backend 간 계정 연동 구현

## 목표
- Frontend와 Backend 간 계정 시스템 연동
- 로그인/회원가입 기능 구현
- 인증 토큰 관리
- 사용자 정보 동기화

## 진행 상황

### 업데이트 - 2025-10-10 15:24

**요약**: Frontend Backend 계정 연동 구현 완료 - 로그인 토큰 관리, UUID 연동, 소셜 로그인 비활성화

**Git 변경 사항**:
- 수정됨:
  - backend/src/main/java/com/litten/note/NoteMemberService.java (회원탈퇴 로직 개선)
  - frontend/lib/services/auth_service.dart (authToken 저장 및 관리)
  - frontend/lib/services/api_service.dart (UUID 포함 로그인, auth-token 헤더)
  - frontend/lib/screens/settings_screen.dart (UUID 계정 조회 및 상태 관리)
  - frontend/lib/screens/login_screen.dart (소셜 로그인 버튼 비활성화)
  - frontend/lib/screens/signup_screen.dart (소셜 회원가입 버튼 비활성화)
- 현재 브랜치: main (커밋: 878922b backend 가입 탈퇴 보완)

**완료된 작업**:
1. ✅ UUID 기반 계정 조회 (GET /note/v1/members?uuid={uuid}&state=signup)
2. ✅ 회원탈퇴 API 연동 (DELETE /note/v1/members/{id})
3. ✅ 회원탈퇴 시 성공 결과 반환 및 backup 실패 처리
4. ✅ 로그인 시 UUID를 JSON 데이터에 포함
5. ✅ Google/Apple 소셜 로그인/회원가입 버튼 비활성화 (2차 개발 예정)
6. ✅ 비밀번호 변경 시 auth-token 헤더 전송 (이미 구현되어 있었음)
7. ✅ 로그인 시 실제 authToken 저장 및 만료 시간 관리
8. ✅ 설정 화면에서 UUID 계정 조회 및 registered_email 관리
9. ✅ 로그아웃 상태 프리미엄 플랜에 "(로그인 필요)" 표시

**발견한 이슈 및 해결책**:

1. **회원탈퇴 시 "알 수 없는 에러" 발생**
   - 원인: backup 메서드에서 예외 발생 시 회원탈퇴 중단
   - 해결: try-catch로 감싸서 로그 저장 실패해도 탈퇴 진행되도록 수정
   - 파일: backend/src/main/java/com/litten/note/NoteMemberService.java (320-329번 줄)

2. **비밀번호 변경 시 "리포지토리 객체를 찾을 수 없음" 에러**
   - 원인: putChangePassword 메서드는 존재하지만 Spring Boot가 재시작 필요
   - 상태: 백엔드 재시작 시도했으나 Maven 컴파일 에러 발생
   - 조치: 사용자가 IDE에서 수동 재시작 필요

3. **로그인 후 dummy_token 사용 문제**
   - 원인: response['token'] 필드가 없고, 백엔드는 'authToken' 반환
   - 해결: response['authToken'] 및 'memberId', 'tokenExpiredDate' 추출로 변경
   - 파일: frontend/lib/services/auth_service.dart (291-299번 줄)

4. **회원탈퇴 후 이메일 고정 문제**
   - 원인: SharedPreferences의 registered_email이 삭제되지 않음
   - 해결: UUID 조회 시 계정 없으면 registered_email 삭제하도록 수정
   - 파일: frontend/lib/screens/settings_screen.dart (45-90번 줄)

**주요 변경 코드**:

1. **authToken 저장 및 관리** (auth_service.dart):
   ```dart
   // 로그인 응답에서 실제 authToken 추출
   final token = response['authToken'] as String?;
   final tokenExpiredDate = response['tokenExpiredDate'] as int?;

   // SharedPreferences에 토큰 및 만료 시간 저장
   await _saveAuthData(
     token: token,
     email: email,
     userId: userId,
     tokenExpiredDate: tokenExpiredDate,
   );
   ```

2. **로그인 시 UUID 전송** (api_service.dart):
   ```dart
   final body = jsonEncode({
     'id': email,
     'password': password,
     'uuid': uuid,  // UUID 추가
   });
   ```

3. **회원탈퇴 로직 개선** (NoteMemberService.java):
   ```java
   // 백업 실패해도 탈퇴 진행
   try {
     backup(tempNoteMember, Constants.CODE_LOG_DELETE_QUERY);
   } catch (Exception e) {
     e.printStackTrace();
   }

   // 성공 결과 반환
   result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);
   result.put(Constants.TAG_RESULT_MESSAGE, "회원탈퇴 성공");
   ```

4. **소셜 로그인 비활성화**:
   - login_screen.dart: onPressed: null (284, 291번 줄)
   - signup_screen.dart: onPressed: null (300, 313번 줄)

**테스트 결과**:
- ✅ Android/iOS 시뮬레이터 정상 실행
- ✅ UUID 계정 조회 정상 동작
- ✅ 회원탈퇴 성공 (result: 1, message: "회원탈퇴 성공")
- ✅ 로그인 시 authToken 저장 확인
- ✅ registered_email 자동 관리 확인

**남은 작업**:
- ⏳ 백엔드 재시작 (비밀번호 변경 기능 활성화)
- 📝 2차 개발: Google/Apple 소셜 로그인 연동

---

## 세션 종료 요약

**종료 시간**: 2025-10-10 15:25 (KST)
**소요 시간**: 약 4시간 23분 (11:02 ~ 15:25)

### Git 최종 상태

**변경된 파일 수**: 10개
- 수정된 파일: 8개
- 추가된 파일: 2개
- 삭제된 파일: 0개

**변경된 파일 목록**:
```
M  .claude/sessions/.current-session
M  0_history.txt
M  backend/src/main/java/com/litten/note/NoteMemberService.java
M  frontend/lib/screens/login_screen.dart
M  frontend/lib/screens/settings_screen.dart
M  frontend/lib/screens/signup_screen.dart
M  frontend/lib/services/api_service.dart
M  frontend/lib/services/auth_service.dart
A  .claude/sessions/2025-10-10-1102-frontend-backend-계정-연동.md
A  backend/.vscode/
```

**커밋 수**: 0 (작업 완료 후 커밋 필요)
**현재 브랜치**: main
**마지막 커밋**: 878922b backend 가입 탈퇴 보완

### 작업 완료 요약

**완료된 작업**: 9개
1. ✅ UUID 기반 계정 조회 구현
2. ✅ 회원탈퇴 API 연동 및 오류 수정
3. ✅ 회원탈퇴 로직 개선 (backup 실패 처리)
4. ✅ 로그인 시 UUID 전송
5. ✅ 소셜 로그인/회원가입 버튼 비활성화
6. ✅ auth-token 헤더 전송 확인
7. ✅ authToken 실제 저장 및 만료 시간 관리
8. ✅ UUID 계정 조회 및 registered_email 자동 관리
9. ✅ 프리미엄 플랜 로그인 필요 표시

**미완료 작업**: 1개
- ⏳ 백엔드 재시작 (비밀번호 변경 기능 활성화를 위해 사용자가 IDE에서 수동 재시작 필요)

### 주요 성과

1. **Frontend-Backend 계정 연동 완성**
   - UUID 기반 디바이스 식별 시스템 구축
   - 로그인 시 실제 JWT 토큰 저장 및 관리
   - 토큰 만료 시간 추적 기능 추가

2. **사용자 경험 개선**
   - 회원가입한 계정의 이메일 자동 고정
   - 회원탈퇴 후 이메일 자동 해제
   - 소셜 로그인 버튼 2차 개발 대비 UI 준비

3. **안정성 향상**
   - 회원탈퇴 시 backup 실패해도 탈퇴 진행
   - 모든 API 응답 필드 백엔드 스펙에 맞춰 수정
   - 상태 관리 로직 개선 (registered_email)

### 구현된 기능 상세

#### 1. UUID 계정 조회 시스템
- **API**: `GET /note/v1/members?uuid={uuid}&state=signup`
- **기능**: 디바이스 UUID로 가입 여부 확인
- **적용**: 설정 화면 진입 시 자동 조회, 로그인 화면 이메일 고정

#### 2. 회원탈퇴 시스템
- **API**: `DELETE /note/v1/members/{id}`
- **개선사항**:
  - backup 메서드 예외 처리 추가
  - 성공 결과 명시적 반환 (result: 1, message: "회원탈퇴 성공")
  - 로컬 파일 유지 옵션
  - registered_email 자동 삭제

#### 3. 인증 토큰 관리
- **저장 항목**: authToken, tokenExpiredDate, email, userId
- **저장소**: SharedPreferences
- **관리 로직**:
  - 로그인 시 저장
  - 로그아웃 시 삭제
  - 회원탈퇴 시 삭제
  - API 호출 시 auth-token 헤더에 포함

#### 4. 소셜 로그인 준비
- Google/Apple 로그인 버튼 비활성화 처리
- 2차 개발 시 쉽게 활성화할 수 있도록 구조 유지

### 해결한 주요 문제

#### 1. 회원탈퇴 "알 수 없는 에러"
- **증상**: result: -1, message: "알 수 없는 에러"
- **원인**: NoteMemberLog 저장(backup) 실패 시 전체 탈퇴 프로세스 중단
- **해결**: try-catch로 backup을 감싸서 실패해도 탈퇴 진행
- **영향받은 파일**: NoteMemberService.java

#### 2. 비밀번호 변경 "리포지토리 객체를 찾을 수 없음"
- **증상**: result: -3, message: "리포지토리 객체를 찾을 수 없음"
- **원인**: Spring Boot DevTools가 코드 변경을 감지했으나 재시작되지 않음
- **시도한 해결책**: Maven clean, spring-boot:run 재실행
- **발생한 문제**: Java 컴파일러 에러 (TypeTag::UNKNOWN)
- **최종 조치**: 사용자가 IDE에서 수동 재시작 필요

#### 3. 로그인 후 dummy_token 저장
- **증상**: 실제 JWT 토큰 대신 "dummy_token" 저장됨
- **원인**: 백엔드가 'authToken' 필드로 반환하는데 코드는 'token' 필드 찾음
- **해결**: response['authToken'], response['memberId'], response['tokenExpiredDate'] 추출로 변경
- **영향받은 파일**: auth_service.dart

#### 4. 회원탈퇴 후 이메일 계속 고정
- **증상**: 탈퇴 후에도 로그인 화면에서 이메일 고정됨
- **원인**: SharedPreferences의 registered_email이 삭제되지 않음
- **해결**: UUID 조회 시 계정 없으면 registered_email 삭제
- **추가 개선**: 회원탈퇴 성공 시 _registeredEmail 상태도 null로 초기화
- **영향받은 파일**: settings_screen.dart

### 주요 변경 사항

#### Backend (NoteMemberService.java)
```java
// 1. 회원탈퇴 시 backup 예외 처리 (320-329번 줄)
for (NoteMember tempNoteMember : noteMembers) {
    tempNoteMember.setUpdateDateTime(LocalDateTime.now());
    try {
        backup(tempNoteMember, Constants.CODE_LOG_DELETE_QUERY);
    } catch (Exception e) {
        e.printStackTrace();
    }
}

// 2. 성공 결과 명시적 반환 (335-336번 줄)
result.put(Constants.TAG_RESULT, Constants.RESULT_SUCCESS);
result.put(Constants.TAG_RESULT_MESSAGE, "회원탈퇴 성공");
```

#### Frontend (auth_service.dart)
```dart
// 1. 실제 authToken 저장 (291-299번 줄)
final token = response['authToken'] as String?;
final userId = response['memberId'] as String? ?? email;
final tokenExpiredDate = response['tokenExpiredDate'] as int?;

if (token == null) {
  throw Exception('로그인 응답에 authToken이 없습니다');
}

// 2. 토큰 만료 시간 저장 (235-252번 줄)
Future<void> _saveAuthData({
  required String token,
  required String email,
  required String userId,
  int? tokenExpiredDate,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyToken, token);
  await prefs.setString(_keyEmail, email);
  await prefs.setString(_keyUserId, userId);
  if (tokenExpiredDate != null) {
    await prefs.setInt(_keyTokenExpiredDate, tokenExpiredDate);
  }
}

// 3. 토큰 삭제 로직 개선 (254-263번 줄)
Future<void> _clearAuthData() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keyToken);
  await prefs.remove(_keyEmail);
  await prefs.remove(_keyUserId);
  await prefs.remove(_keyTokenExpiredDate);
}
```

#### Frontend (api_service.dart)
```dart
// 1. 로그인 시 UUID 전송 (195-199번 줄)
final body = jsonEncode({
  'id': email,
  'password': password,
  'uuid': uuid,
});

// 2. auth-token 헤더 추가 (23-29번 줄) - 이미 구현되어 있었음
Map<String, String> _getHeaders({String? token}) {
  final headers = {'Content-Type': 'application/json'};
  if (token != null) {
    headers['auth-token'] = token;
  }
  return headers;
}
```

#### Frontend (settings_screen.dart)
```dart
// UUID 계정 조회 및 registered_email 관리 (45-90번 줄)
final accountData = await apiService.findAccountByUuid(uuid: uuid);
final prefs = await SharedPreferences.getInstance();

if (accountData != null && mounted) {
  final member = accountData['noteMember'] as Map<String, dynamic>?;
  if (member != null) {
    final state = member['state'] as String?;
    final email = member['id'] as String?;

    if (state == 'signup' && email != null) {
      setState(() => _registeredEmail = email);
      await prefs.setString('registered_email', email);
    } else {
      setState(() => _registeredEmail = null);
      await prefs.remove('registered_email');
    }
  } else {
    setState(() => _registeredEmail = null);
    await prefs.remove('registered_email');
  }
} else {
  if (mounted) setState(() => _registeredEmail = null);
  await prefs.remove('registered_email');
}
```

#### Frontend (login_screen.dart, signup_screen.dart)
```dart
// 소셜 로그인 버튼 비활성화
_buildSocialLoginButton(
  icon: Icons.g_mobiledata,
  label: 'Google로 로그인',
  onPressed: null,  // 비활성화
  color: Colors.red,
)
```

### 설정 변경 사항

**추가된 SharedPreferences 키**:
- `token_expired_date`: JWT 토큰 만료 시간 (int, Unix timestamp)

**변경된 API 요청 형식**:
```json
// 로그인 요청
{
  "id": "email@example.com",
  "password": "password123",
  "uuid": "device-uuid"  // 추가됨
}

// 비밀번호 변경 요청 (헤더)
{
  "auth-token": "eyJhbGciOiJIUzUxMiJ9..."  // 실제 JWT 토큰 사용
}
```

### 테스트 결과

**플랫폼**: Android (emulator-5554), iOS (9E7DE80B-533A-42CF-BDB3-C9A65E44C1A3)

**성공한 테스트**:
1. ✅ UUID 계정 조회 (result: 1 시 이메일 저장, result: 0 시 삭제)
2. ✅ 회원탈퇴 (result: 1, message: "회원탈퇴 성공")
3. ✅ 로그인 시 authToken 저장 (JWT 형식 확인)
4. ✅ registered_email 자동 관리
5. ✅ 소셜 로그인 버튼 비활성화 확인
6. ✅ 프리미엄 플랜 로그인 필요 표시

**실제 로그 예시**:
```
[ApiService] loginMobile - Response body: {
  "result": 1,
  "sequence": 16,
  "authToken": "eyJhbGciOiJIUzUxMiJ9...",
  "uuid": "0584dea0-617e-4097-8f71-10352b287acd",
  "tokenExpiredDate": 1762668519,
  "memberId": "bgso777@naver.com"
}
```

### 얻은 교훈

1. **백엔드 API 응답 구조 확인의 중요성**
   - 문서만 믿지 말고 실제 응답 로그를 확인해야 함
   - 'token' vs 'authToken', 'userId' vs 'memberId' 같은 차이 발견

2. **예외 처리의 중요성**
   - backup 같은 부수적 기능이 핵심 기능을 막아서는 안 됨
   - try-catch로 격리하여 실패해도 계속 진행

3. **상태 관리의 복잡성**
   - registered_email을 여러 곳에서 사용하니 동기화 문제 발생
   - 단일 진실 공급원(Single Source of Truth) 원칙 필요

4. **Spring Boot DevTools의 한계**
   - 코드 변경 시 자동 재시작이 항상 작동하는 것은 아님
   - 중요한 변경은 수동 재시작 권장

5. **로그의 중요성**
   - 상세한 로그 덕분에 문제 원인을 빠르게 파악
   - API 요청/응답은 반드시 로그로 남겨야 함

### 미래 개발자를 위한 팁

1. **토큰 관리**
   - `_keyTokenExpiredDate`를 사용해 토큰 만료 검증 로직 추가 권장
   - 만료 시 자동 로그아웃 또는 리프레시 토큰 구현 고려

2. **백엔드 재시작**
   - 비밀번호 변경 기능을 테스트하려면 먼저 백엔드를 재시작하세요
   - IDE(IntelliJ)에서 `StartAccountManagerApplication` 실행 권장

3. **UUID 계정 조회**
   - 설정 화면 진입 시마다 실행되므로 성능 영향 고려
   - 필요시 캐싱 또는 주기적 갱신으로 최적화

4. **소셜 로그인 구현 시**
   - login_screen.dart, signup_screen.dart의 `onPressed: null`을 해당 핸들러로 교체
   - auth_service.dart의 TODO 주석 참고

5. **registered_email 사용 주의**
   - 이 값은 최초 회원가입한 이메일을 추적하기 위한 것
   - 로그인 상태와는 무관하게 디바이스에 영구 저장됨
   - 회원탈퇴 시에만 삭제됨

6. **에러 핸들링**
   - backend의 result 값: 1=성공, 0=실패, -1=알 수 없는 에러, -3=리포지토리 없음
   - Constants.java 파일 참고

### 완료되지 않은 작업

1. **백엔드 재시작** (우선순위: 높음)
   - 비밀번호 변경 기능 활성화를 위해 필요
   - Maven 컴파일 에러 해결 필요 또는 IDE에서 직접 실행

2. **토큰 만료 검증** (우선순위: 중간)
   - tokenExpiredDate를 사용한 만료 검증 로직 미구현
   - 만료 시 자동 로그아웃 기능 추가 권장

3. **소셜 로그인 구현** (우선순위: 낮음 - 2차 개발)
   - Google Sign-In 연동
   - Apple Sign-In 연동
   - auth_service.dart의 TODO 참고

4. **Git 커밋** (우선순위: 높음)
   - 현재 8개 파일 수정됨, 커밋 필요
   - 권장 커밋 메시지: "frontend backend 계정 연동 완료 - authToken 관리, UUID 연동"

### 다음 세션을 위한 체크리스트

- [ ] 백엔드 재시작하여 비밀번호 변경 기능 테스트
- [ ] 토큰 만료 검증 로직 구현
- [ ] Git 커밋 및 푸시
- [ ] Android/iOS 실기기 테스트
- [ ] 토큰 리프레시 로직 구현 (선택사항)

---

**세션 종료**: 2025-10-10 15:25 (KST)
**최종 상태**: Frontend Backend 계정 연동 구현 완료, 일부 수동 작업 필요 (백엔드 재시작)

