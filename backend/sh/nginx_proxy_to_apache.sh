#!/bin/bash

set -e

echo "========================================"
echo "Nginx 프록시 설정 변경"
echo "80 -> 8080 (Apache) 포워딩"
echo "========================================"
echo ""

# 디렉토리 확인
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

echo "Nginx 설정 파일 생성 중..."

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

echo "Nginx 설정 활성화 중..."

# 기존 설정 비활성화
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/www
rm -f /etc/nginx/sites-enabled/tomcat-proxy

# 새 설정 활성화
ln -sf /etc/nginx/sites-available/apache-proxy /etc/nginx/sites-enabled/

echo "✓ Nginx 설정 활성화 완료"
echo ""

# nginx.conf에 sites-enabled include 확인
if ! grep -q "sites-enabled" /etc/nginx/nginx.conf; then
    echo "sites-enabled include 추가 중..."
    sed -i '/http {/a \    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
fi

echo "Nginx 설정 테스트 중..."

nginx -t

if [ $? -eq 0 ]; then
    echo "✓ Nginx 설정 테스트 통과"
    echo ""
    
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
echo "서비스 포트 구성:"
echo "  - Nginx (프록시): 80 -> Apache 8080"
echo "  - Apache (직접): 8080"
echo "  - Tomcat (직접): 8081"
echo ""
echo "접속 테스트:"
echo "  http://203.245.29.74 (Nginx -> Apache)"
echo "  http://203.245.29.74:8080 (Apache 직접)"
echo "  http://203.245.29.74:8081 (Tomcat 직접)"
echo ""
echo "========================================"
