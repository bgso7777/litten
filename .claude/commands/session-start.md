시간대는 한국시간(Asia korea 시간대) 입니다. 
새로운 개발 세션을 시작하려면 `.claude/sessions/` 디렉토리에 `YYYY-MM-DD-HHMM-$ARGUMENTS.md` 형식(또는 이름이 없다면 `YYYY-MM-DD-HHMM.md`)의 세션 파일을 생성하세요.

세션 파일은 다음으로 시작해야 합니다:
1. 세션 이름과 타임스탬프를 제목으로 작성
2. 시작 시간을 포함한 세션 개요(overview) 섹션
3. 목표(goals) 섹션 (명확하지 않다면 사용자에게 목표를 요청)
4. 업데이트를 위한 비어있는 진행 상황(progress) 섹션
5. 모든 파일은 UTF-8 케릭터 셋으로 합니다. 
6. 세션 파일의 내용은 반드시 한글로 작성해야 합니다.

파일을 생성한 후 `.claude/sessions/.current-session` 파일을 생성하거나 업데이트하여 현재 활성화된 세션 파일 이름을 추적하세요.

세션이 시작되었는지 확인하고 사용자에게 다음을 상기시켜 주세요:
- `/project:session-update` 명령어로 세션을 업데이트할 수 있습니다.
- `/project:session-end` 명령어로 세션을 종료할 수 있습니다.
