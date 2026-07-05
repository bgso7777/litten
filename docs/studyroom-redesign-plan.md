# 채팅 → 스터디룸(Study Room) 재설계 기획안

작성일: 2026-07-05 (KST) · 상태: 기획 확정 대기

## 0. 확정된 방향 (사용자 결정)

- **범위**: 개념까지 재설계 (표기만 바꾸는 수준이 아님)
- **스터디룸 정의**: **학습자료 공유 방** — 방 안에 참여자 + 공유된 학습자료(노트/녹음/필기/PDF/요약/퀴즈) + 대화가 함께 담긴다. 기존 "그룹"을 "룸"으로 승격한다.
- **나와의 대화(셀프챗)**: **'나만의 스터디룸'으로 흡수** (개념 통일, 로컬 데이터 키는 유지)
- **메뉴 위치**: 홈 탭(하단 네비 0번, 맨 왼쪽) **유지**, 라벨/아이콘만 갱신
- **대화 방식**: **비실시간 유지** (기존 새로고침 방식 그대로, 서버 `/messages` 변경 없음)
- **아이콘**: `Icons.forum`(겹친 말풍선)으로 확정

---

## 1. 개념 매핑 (기존 → 스터디룸 모델)

| 기존 채팅 개념 | 스터디룸 모델에서 | 처리 |
|---|---|---|
| ③ 그룹(share-group) | **스터디룸 (다인 룸)** | 개념 승격 — 룸의 기본형 |
| ② 나와의 대화(selfChat) | **나만의 스터디룸 (1인 룸)** | 흡수 — 룸의 특수형 |
| ① 공유/메시지(message) | 룸 안의 **대화 + 자료 공유** | 룸의 내용물로 편입 |
| ④ 공유받음/공유한, 대화방 | 룸 목록 / 룸 상세의 **표현 계층** | 룸 중심 뷰로 재구성 |

> 핵심: "채팅방 하나 = 스터디룸 하나". 방 안에 **자료 탭 + 대화 탭**이 공존하는 구조로 격상.

---

## 2. 정보구조(IA) / 메뉴

```
MainTabScreen (하단 5탭) — 구조 불변
├── [0] ★스터디룸★  (구 홈=채팅)   ← 라벨/아이콘만 변경
│      ├── 룸 목록: 나만의 스터디룸 · 1:1 룸 · 다인 룸
│      └── 룸 상세: [자료] 공유된 학습자료  /  [대화] 메시지
├── [1] 캘린더
├── [2] + (노트)
├── [3] 리마인드
└── [4] 설정
```

- 하단 네비 0번 라벨: 현재 빈 문자열 → **"스터디룸"** 텍스트 라벨 신규 추가 검토
- 아이콘: 말풍선(`RoundChatBubbleIcon`) → **`Icons.forum`(겹친 말풍선)으로 확정**. 기존 말풍선과 시각적 연속성 유지하며 "여럿이 대화" 의미 전달

---

## 3. 화면 흐름 (룸 상세의 자료/대화 통합)

- 룸 목록 진입 → 룸 선택 → **룸 상세**
- 룸 상세 상단 세그먼트: `[자료]` `[대화]`
  - **자료 탭**: 그 룸에 공유된 노트/녹음/필기/PDF/요약/퀴즈 (기존 공유받음/공유한 + 파일 종류 칩 재활용)
  - **대화 탭**: 기존 말풍선 채팅 UI 그대로
- FAB: 현재 "새 채팅" → "**새 스터디룸**" (룸 생성)

---

## 4. 데이터 모델 — 유지 vs 변경

### 4-1. 백엔드: **전면 리네임** (사용자 결정: 내부+API+DB 모두)
- **바꿈**: 자바 패키지·클래스·필드명, REST API 경로, DB 테이블/컬럼 물리명 → 모두 스터디룸 도메인으로.
- **동결(안전)**: 요청/응답 JSON 와이어 키(`targetType`, `groupId`, `groups` 등), `target_type` 값 `'group'`, `conv_key` 접두사 `'u:'/'g:'`. → 통신 계약·기존 데이터 매칭 보존.
- **무중단**: 컨트롤러 경로를 `{신규, 구}` 배열 병행 노출 → 구버전 앱도 계속 동작.
- 상세는 아래 §8 참조.

### 4-2. 프론트: 유지할 것 vs 바꿀 것
- **유지(데이터 호환)**: SharedPreferences 키(`self_chats`, `self_chat_msgs_*`), 로컬 폴더(`self_chat_files/`), 서버 엔드포인트 상수, 상태값 문자열 `'chat'`(리네임 시 6곳 동시 수정 필요하므로 신중)
- **바꿀 것**: 화면 표시 한글 문자열, Dart 위젯/함수 식별자(선택), 룸 목록/상세 UI 재구성, 라벨/아이콘

---

## 5. 단계별 구현 계획 (합의 후 진행)

작은 단위로 쪼개 각 단계마다 에뮬레이터 검증. (CLAUDE.md: 대규모 일괄 변경 지양)

- **1단계 — 표기/아이콘 (저위험)** ✅ *코드 완료 (2026-07-05)*: 화면 한글 문자열 "채팅"→"스터디룸" 계열로, 하단 네비 아이콘 `RoundChatBubbleIcon`→`Icons.forum` 교체(라벨은 아이콘만 유지). 기능 동일. `flutter analyze` 신규 오류 없음. 폰·태블릿 재실행 검증 진행 중.
  - 변경: `main_tab_screen.dart`(아이콘, FAB 툴팁 '새 스터디룸', unused import 제거), `home_dashboard_screen.dart`('새 스터디룸'/'스터디룸 이름'/'나만의 스터디룸' 등 문자열 8곳)
- **2단계 — 룸 개념 통일 (중위험)**: 룸 목록에서 '나만의 스터디룸'(셀프챗)·1:1·다인 룸을 하나의 "룸" 목록으로 표현 통일. 데이터 소스는 그대로.
- **3단계 — 룸 상세 자료/대화 분리 (핵심)**: 룸 상세를 `[자료]`/`[대화]` 세그먼트로 재구성. 자료 탭에 공유 학습자료 편입.
- **4단계 — (선택) 다국어/식별자 정리**: 신규 문자열 ARB 키화(30개 언어), Dart 식별자 리팩터링.

---

## 6. 리스크 / 주의

- 상태값 `'chat'` 리네임은 6개 비교 지점([home_dashboard_screen.dart](../frontend/lib/screens/home_dashboard_screen.dart) 등) 동시 수정 필요 → 1단계에서는 값은 두고 표시만 변경 권장.
- `ShareTabTitle` 위젯: 이름은 "Share"인데 실제 채팅 헤더 → 재설계 시 네이밍 정리 대상.
- 셀프챗 로컬 데이터 키를 바꾸면 기존 사용자 '나와의 대화'가 사라짐 → **키 문자열 절대 유지**.
- l10n: 현재 채팅 문자열은 ARB에 전혀 없고 Dart 하드코딩. 스터디룸 표기를 다국어로 하려면 별도 ARB 작업 필요(4단계).

---

## 7. 결정 완료

- 표기: **"스터디룸"**(한글 붙임) / 하단 네비 **아이콘만**(라벨 없음) / 아이콘 **`Icons.forum`** / 대화 **비실시간 유지**
- 백엔드: **전면 리네임(내부+API+DB)**, JSON 키/enum 값 동결

---

## 8. 상세 실행 계획 (2·3단계 + 백엔드 전면 리네임)

전제: JSON 와이어 키 동결, `target_type` 값·`conv_key` 접두사 동결, 셀프룸 로컬 키(`self_chats` 등) 동결.
운영 DB 적용·WAR 재배포는 코드+SQL 작성/로컬 컴파일 검증까지만. 실서버 적용은 배포 담당(사장님) 통제.

### 8-A. 백엔드 리네임 스킴

패키지/클래스:
| 현재 | 신규 |
|---|---|
| `note.share` 패키지 | `note.studyroom` |
| `ShareGroup` / `note_share_group` | `StudyRoom` / `note_study_room` |
| `ShareGroupMember` / `note_share_group_member` | `StudyRoomMember` / `note_study_room_member` |
| `ShareGroup{Controller,Service,Repository}` | `StudyRoom{Controller,Service,Repository}` |
| `FileShare` / `note_file_share` | `RoomShare` / `note_room_share` |
| `FileShareDelivery` / `note_file_share_delivery` | `RoomShareDelivery` / `note_room_share_delivery` |
| `note.message` 패키지 | `note.studyroom.message` |
| `NoteMessage` / `note_message` | `RoomMessage` / `note_room_message` |
| `NoteMessageDelivery` / `note_message_delivery` | `RoomMessageDelivery` / `note_room_message_delivery` |
| `MessageController`/`Service` | `RoomMessageController`/`Service` |
| `note.selfchat` 패키지 | `note.selfroom` |
| `SelfChat` / `note_self_chat` | `SelfStudyRoom` / `note_self_study_room` |
| `SelfChatItem` / `note_self_chat_item` | `SelfStudyRoomItem` / `note_self_study_room_item` |
| `SelfChat{Controller,Service,Repository}` | `SelfStudyRoom{...}` |
| `note.hidden` 패키지 | `note.hiddenroom` |
| `HiddenConversation` / `note_hidden_conversation` | `HiddenRoom` / `note_hidden_room` |
| `HiddenConversation{Controller,Service,Repository}` | `HiddenRoom{...}` |

컬럼 리네임:
- `note_study_room_member.group_id` → `room_id` (필드 `groupId`→`roomId`, 파생쿼리 `findByGroupId...`→`findByRoomId...`)
- `note_room_message.group_id` → `room_id` (필드 `groupId`→`roomId`)
- `note_room_share.group_id` → `room_id` (필드 `groupId`→`roomId`)
- `note_self_study_room_item.self_chat_id` → `room_id` (필드 `selfChatId`→`roomId`, 파생쿼리 갱신)

**동결(변경 금지)**: `target_type` 값 `'user'/'group'`, `conv_key` 값 접두사, `note_message_delivery.message_id`(→`note_room_message_delivery.message_id` 테이블만 rename, 컬럼 유지), `member_id`/`owner_member_id`/`sender_member_id`/`client_id`/`stored_path`/`file_*` 컬럼.

**컴파일러가 못 잡는 문자열 주의**:
- `@Entity(name="...")` 논리명: `FileShareRepository`의 `@Query("update FileShare ...")`→`RoomShare`, `NoteMessageRepository`의 `@Query("update NoteMessage ...")`→`RoomMessage`.
- cross-package import 유일 지점: `MessageService`의 `import com.litten.note.share.*` → `note.studyroom.*`.

### 8-B. API 경로 매핑 (컨트롤러 메서드에 `{신규, 구}` 배열 병행)
| 현재 | 신규 |
|---|---|
| `/note/v1/share-groups` (+하위) | `/note/v1/study-rooms` |
| `/note/v1/shares` (+하위) | `/note/v1/room-shares` |
| `/note/v1/messages` (+하위) | `/note/v1/room-messages` |
| `/note/v1/self-chats` (+하위) | `/note/v1/my-study-rooms` |
| `/note/v1/hidden-conversations` | `/note/v1/hidden-rooms` |

### 8-C. DB 마이그레이션 SQL (신규 파일 `backend/query/migration_20260705_study_room.sql`)
- Forward: `RENAME TABLE`(9개) → `ALTER TABLE ... CHANGE COLUMN`(group_id/self_chat_id→room_id) → (선택)인덱스명 정리.
- Rollback: 역순 완비. FK 없음·무손실. 배포 전 대상 테이블 `mysqldump` 백업.
- 엔티티 `@Table`/`@Column`과 1:1 동기화.

### 8-D. 프론트 변경
- **api_service.dart 상수 5줄**(L38–42): 위 신규 경로로 교체. JSON 키 동결이라 파싱·UI 무변경.
- **2단계(문자열)**: `_startNewChat` 다이얼로그 탭 라벨 `1:1/그룹/나`→`1:1 룸/그룹 룸/나만의 룸`, `'새 그룹 만들기'`→`'새 그룹 룸 만들기'`, `'나와의 대화'`→`'나만의 스터디룸 만들기'`, `_NewChatOneToOneTab`의 `'대화 시작'`→`'룸 만들기'`. **라우팅 키 문자열(`'u:'`,`'g:'`,`'__newgroup__'`,`'__selfchat__'`) 절대 불변**. 상태값 `'chat'` 유지.
- **3단계(핵심)**: `_buildChatRoom`을 헤더 + `[대화]/[자료]` 세그먼트 + 본문 조건분기로 재구성.
  - `_ShareSectionState`에 `String _roomTab='chat'`, `String _roomMaterialKind='all'` 지역 필드 추가(전역 `homeChatFileKind` 재사용 금지).
  - [대화]: 기존 말풍선 블록 그대로. 입력창은 대화 탭에서만.
  - [자료]: `c.items.where((it)=>!it.isMessage)` 룸별 필터 + 종류 칩(`_shareFileKind`/`_shareFileTypeIcon`/`_openSharedSnapshot`/`_openSelfChatFile` 재사용).
  - 스크롤 가드: `_scrollChatToBottom` postFrame 콜백에 `_roomTab=='chat'` 가드. 룸 전환/뒤로가기 시 `_roomTab='chat'` 리셋.
  - 전역 `_HomeChipBar`/`_buildChatFileKindList`/`_buildSharedFileList`는 당장 삭제 금지(후속 정리).

### 8-E. 실행 순서 & 검증
1. 백엔드: 티어 A→B→C 리네임 + 경로 배열 + SQL 파일 작성 → `mvn compile` 그린.
2. 프론트: api_service 상수 → 2단계 문자열 → 3단계 세그먼트 → `flutter analyze`.
3. 통합: 폰·태블릿 에뮬레이터로 룸 진입/자료↔대화 전환/전송 스모크 테스트.
4. 운영: (사장님) DB 백업→SQL 적용→WAR 재배포→앱 배포. 경로 배열 병행이라 무중단.
