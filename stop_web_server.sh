#!/bin/bash

echo "🛑 리튼 앱 웹 서버 중지 중..."

# PID 파일에서 서버 PID 읽기
PID_FILE="/tmp/litten_web_server.pid"
if [ -f "$PID_FILE" ]; then
    SERVER_PID=$(cat "$PID_FILE")
    if kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID"
        echo "✅ 서버 (PID: $SERVER_PID) 중지됨"
    else
        echo "⚠️ PID $SERVER_PID 프로세스를 찾을 수 없습니다."
    fi
    rm -f "$PID_FILE"
else
    echo "⚠️ PID 파일을 찾을 수 없습니다."
fi

# 추가로 관련 프로세스들 정리
pkill -f "python3 -m http.server 8080" 2>/dev/null && echo "✅ HTTP 서버 프로세스 정리됨"
pkill -f "flutter.*web-server" 2>/dev/null && echo "✅ Flutter 서버 프로세스 정리됨"

# 포트 사용 상태 확인
if ss -tlnp | grep -q ":8080"; then
    echo "⚠️ 포트 8080이 여전히 사용 중입니다."
    echo "사용 중인 프로세스:"
    ss -tlnp | grep ":8080"
else
    echo "✅ 포트 8080이 해제되었습니다."
fi

# 로그 파일 정리 (선택사항)
if [ "$1" = "--clean-logs" ]; then
    rm -f /tmp/litten_web_server.log
    echo "🧹 로그 파일 정리됨"
fi

echo ""
echo "🟢 서버 중지 완료"