세션 관리 시스템 도움말을 표시합니다:

## 세션 관리 명령어

세션 시스템은 개발 작업을 문서화하여 나중에 참고할 수 있도록 도와줍니다.

### 사용 가능한 명령어:

- `/project:session-start [이름]` - 선택적 이름과 함께 새 세션 시작
- `/project:session-update [노트]` - 현재 세션에 노트 추가  
- `/project:session-end` - 세션 종료 및 종합 요약 작성
- `/project:session-list` - 모든 세션 파일 목록 보기
- `/project:session-current` - 현재 세션 상태 보기
- `/project:session-help` - 이 도움말 보기

### 작동 방식:

1. 세션은 `.claude/sessions/` 디렉토리 내의 마크다운 파일로 저장됩니다
2. 파일 형식은 `YYYY-MM-DD-HHMM-name.md`입니다
3. 한 번에 하나의 세션만 활성화될 수 있습니다
4. 세션은 진행 상황, 이슈, 해결책, 배운 점 등을 추적합니다

### 모범 사례:

- 중요한 작업을 시작할 때 세션을 시작하세요
- 중요한 변경 사항이나 발견이 있을 때 정기적으로 업데이트하세요
- 향후 참고를 위해 종합적인 요약과 함께 세션을 종료하세요
- 유사한 작업을 시작하기 전에 과거 세션을 검토하세요

### 예시 워크플로우:

```
/project:session-start refactor-auth
/project:session-update Google OAuth 제한 추가
/project:session-update Next.js 15 params Promise 이슈 수정  
/project:session-end
```