#!/bin/bash

set -e

echo "========================================"
echo "Nginx 프록시 설정"
echo "/litten -> Tomcat 8081 포워딩"
echo "========================================"
echo ""

mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

echo "Nginx 설정 파일 생성 중..."

cat > /etc/nginx/sites-available/litten-proxy << 'NGINX_CONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name www.litten7.com litten7.com;

    access_log /var/log/nginx/litten-proxy.access.log;
    error_log /var/log/nginx/litten-proxy.error.log;

    # /litten 경로는 Tomcat으로 프록시
    location /litten/ {
        proxy_pass http://127.0.0.1:8081/litten/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 타임아웃 설정
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 나머지 경로는 Apache로 프록시
    location / {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
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
rm -f /etc/nginx/sites-enabled/apache-proxy

# 새 설정 활성화
ln -sf /etc/nginx/sites-available/litten-proxy /etc/nginx/sites-enabled/

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
echo "프록시 설정:"
echo "  http://www.litten7.com/litten/* -> Tomcat :8081/litten/*"
echo "  http://www.litten7.com/*        -> Apache :8080/*"
echo ""
echo "예시:"
echo "  http://www.litten7.com/litten/note/v1/members"
echo "    -> http://127.0.0.1:8081/litten/note/v1/members"
echo ""
echo "  http://www.litten7.com/index.html"
echo "    -> http://127.0.0.1:8080/index.html"
echo ""
echo "접속 테스트:"
echo "  curl http://www.litten7.com/litten/"
echo "  curl http://www.litten7.com/"
echo ""
echo "========================================"
