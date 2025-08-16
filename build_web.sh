#!/bin/bash

echo "📦 리튼 앱 웹 빌드 시작..."

# 현재 디렉토리 확인 및 frontend 디렉토리로 이동
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/frontend"

if [ ! -d "lib" ]; then
    echo "🔴 오류: Flutter 프로젝트 디렉토리를 찾을 수 없습니다."
    echo "현재 위치: $(pwd)"
    exit 1
fi

echo "🔍 Flutter 프로젝트 확인됨: $(pwd)"

# Flutter 웹 빌드
echo "⚙️ Flutter 웹 빌드 실행 중..."
../flutter/bin/flutter build web --web-renderer html

if [ $? -ne 0 ]; then
    echo "🔴 Flutter 빌드 실패"
    exit 1
fi

# 빌드 결과 확인
if [ ! -d "build/web" ]; then
    echo "🔴 빌드 디렉토리가 생성되지 않았습니다."
    exit 1
fi

# 빌드된 파일들 확인
BUILD_FILES=$(find build/web -name "*.js" -o -name "*.html" -o -name "*.css" | wc -l)
BUILD_SIZE=$(du -sh build/web | cut -f1)

echo ""
echo "✅ 리튼 앱 웹 빌드 완료!"
echo "📂 빌드 위치: $(pwd)/build/web"
echo "📊 빌드된 파일 수: $BUILD_FILES개"
echo "💾 빌드 크기: $BUILD_SIZE"
echo ""
echo "🚀 서버를 시작하려면: ./start_web_server.sh"