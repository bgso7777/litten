#!/bin/bash

echo "🚀 리튼 앱 웹 서버 시작 중..."

# 기존 서버 프로세스 종료
pkill -f "python3 -m http.server 8080" 2>/dev/null
pkill -f "flutter.*web-server" 2>/dev/null

# 현재 디렉토리 확인 및 frontend 디렉토리로 이동
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/frontend"

if [ ! -d "lib" ]; then
    echo "🔴 오류: Flutter 프로젝트 디렉토리를 찾을 수 없습니다."
    echo "현재 위치: $(pwd)"
    exit 1
fi

# 빌드 디렉토리 확인
if [ ! -d "build/web" ]; then
    echo "🔴 빌드 디렉토리를 찾을 수 없습니다."
    echo "💡 먼저 './build_web.sh'를 실행하여 앱을 빌드해주세요."
    exit 1
fi

echo "✅ 기존 빌드 파일 확인됨"

# 빌드 디렉토리로 이동
cd build/web

# macOS의 로컬 IP 주소 가져오기
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n1)

# 웹 서버 시작 (모든 인터페이스에서 접근 가능)
echo "🌐 웹 서버 시작 중..."
python3 -m http.server 8080 --bind 0.0.0.0 > /tmp/litten_web_server.log 2>&1 &

# 서버 PID 저장
SERVER_PID=$!
echo $SERVER_PID > /tmp/litten_web_server.pid

echo ""
echo "✅ 리튼 앱이 성공적으로 시작되었습니다!"
echo ""
echo "🌍 다음 주소로 접속하세요:"
echo "   http://localhost:8080"
echo "   http://127.0.0.1:8080"
if [ ! -z "$LOCAL_IP" ]; then
    echo "   http://$LOCAL_IP:8080 (네트워크 IP - 다른 기기에서 접근)"
fi
echo ""
echo "🛑 서버를 중지하려면:"
echo "   kill $SERVER_PID"
echo "   또는 pkill -f 'python3 -m http.server 8080'"
echo "   또는 ./stop_web_server.sh"
echo ""

# 서버 상태 확인
sleep 3
if kill -0 $SERVER_PID 2>/dev/null; then
    echo "🟢 서버가 정상적으로 실행 중입니다."
    echo "📝 서버 로그: tail -f /tmp/litten_web_server.log"
else
    echo "🔴 서버 시작에 실패했습니다."
    echo "📝 로그 확인: cat /tmp/litten_web_server.log"
    exit 1
fi