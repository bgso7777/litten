#!/bin/bash

set -e

echo "========================================"
echo "Nginx 리버스 프록시 설정"
echo "80 -> 8080 (Apache) 포워딩"
echo "========================================"
echo ""

# Nginx 설정 파일 생성
cat > /etc/nginx/sites-available/apache-proxy << 'NGINX_CONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    # 접근 로그 및 에러 로그
    access_log /var/log/nginx/apache-proxy.access.log;
    error_log /var/log/nginx/apache-proxy.error.log;

    # Apache로 모든 요청 프록시
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 타임아웃 설정
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
NGINX_CONF

echo "✓ Nginx 설정 파일 생성 완료"
echo ""

# 기존 설정 비활성화
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/www

# 새 설정 활성화
ln -sf /etc/nginx/sites-available/apache-proxy /etc/nginx/sites-enabled/

echo "✓ Nginx 설정 활성화 완료"
echo ""

# Nginx 설정 테스트
echo "Nginx 설정 테스트 중..."
nginx -t

if [ $? -eq 0 ]; then
    echo "✓ Nginx 설정 테스트 통과"
    echo ""

    # Nginx 재시작
    echo "Nginx 재시작 중..."
    systemctl reload nginx

    echo "✓ Nginx 재시작 완료"
else
    echo "✗ Nginx 설정 오류 발생"
    exit 1
fi

echo ""
echo "========================================"
echo "✓✓✓ 설정 완료! ✓✓✓"
echo "========================================"
echo ""
echo "포트 포워딩:"
echo "  Nginx :80 -> Apache :8080"
echo ""
echo "접속 테스트:"
echo "  http://203.245.29.74"
echo ""
echo "설정 파일:"
echo "  /etc/nginx/sites-available/apache-proxy"
echo ""
echo "========================================"
