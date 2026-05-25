#!/bin/bash
# 백엔드 WAR 배포 + yt-dlp 설치 스크립트
# 서버에서 root로 실행: sudo bash deploy_with_ytdlp.sh

BACKEND_HOME="/home/backend"
WAR_FILE="litten-backend-0.0.1.war"
WEBAPPS_DIR="$BACKEND_HOME/tomcat/webapps"

echo "========================================"
echo "배포 + yt-dlp 설치"
echo "========================================"

# 1. yt-dlp 설치
echo "[1/4] yt-dlp 설치 중..."
if command -v yt-dlp &>/dev/null; then
    echo "✓ yt-dlp 이미 설치됨. 업데이트 중..."
    yt-dlp -U
else
    # binary 직접 다운로드 (pip 없어도 됨)
    curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
        -o /usr/local/bin/yt-dlp
    chmod +x /usr/local/bin/yt-dlp
    echo "✓ yt-dlp 설치 완료"
fi
yt-dlp --version

echo ""
echo "[2/4] yt-dlp PATH 확인 (backend 계정에서 실행 가능 여부)..."
su - backend -c "yt-dlp --version" 2>/dev/null && echo "✓ backend 계정에서 yt-dlp 실행 가능" || echo "⚠ PATH 문제 - /etc/environment 확인 필요"

echo ""
echo "[3/4] WAR 파일 배포 중..."
if [ ! -f "/tmp/$WAR_FILE" ]; then
    echo "❌ /tmp/$WAR_FILE 가 없습니다."
    echo "   먼저 WAR 파일을 /tmp 에 업로드하세요:"
    echo "   scp litten-backend-0.0.1.war backend@203.245.29.74:/tmp/"
    exit 1
fi

# 기존 webapps 백업
if [ -d "$WEBAPPS_DIR/ROOT" ]; then
    mv "$WEBAPPS_DIR/ROOT" "$WEBAPPS_DIR/ROOT.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
fi
if [ -f "$WEBAPPS_DIR/$WAR_FILE" ]; then
    mv "$WEBAPPS_DIR/$WAR_FILE" "$WEBAPPS_DIR/$WAR_FILE.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
fi

cp /tmp/$WAR_FILE $WEBAPPS_DIR/
chown backend:backend $WEBAPPS_DIR/$WAR_FILE
echo "✓ WAR 파일 복사 완료: $WEBAPPS_DIR/$WAR_FILE"

echo ""
echo "[4/4] Tomcat 재시작..."
systemctl restart tomcat
sleep 5
systemctl status tomcat | head -10

echo ""
echo "========================================"
echo "✓ 배포 완료!"
echo "서버: http://203.245.29.74:8081"
echo "yt-dlp 테스트: yt-dlp --skip-download --list-subs https://www.youtube.com/watch?v=dQw4w9WgXcQ"
echo "========================================"
