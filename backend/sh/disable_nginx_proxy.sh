#!/bin/bash

set -e

WWW_HOME="/home/www/www"
NGINX_WEB_ROOT="$WWW_HOME/nginx"
APACHE_WEB_ROOT="$WWW_HOME/apache"

echo "========================================"
echo "Nginx 프록시 비활성화"
echo "각 서비스 독립 실행 설정"
echo "========================================"
echo ""

echo "[1/3] Nginx 정적 파일 서빙 설정 중..."

mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled

cat > /etc/nginx/sites-available/static-site << 'NGINX_CONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    root /home/www/www/nginx;
    index index.html index.htm;

    access_log /var/log/nginx/static.access.log;
    error_log /var/log/nginx/static.error.log;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
NGINX_CONF

echo "✓ Nginx 설정 파일 생성 완료"
echo ""

echo "[2/3] 기존 프록시 설정 비활성화 중..."

rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/www
rm -f /etc/nginx/sites-enabled/apache-proxy
rm -f /etc/nginx/sites-enabled/tomcat-proxy
rm -f /etc/nginx/sites-enabled/litten-proxy

ln -sf /etc/nginx/sites-available/static-site /etc/nginx/sites-enabled/

echo "✓ 프록시 설정 비활성화 완료"
echo ""

echo "[3/3] Nginx 재시작 중..."

nginx -t

if [ $? -eq 0 ]; then
    echo "✓ Nginx 설정 테스트 통과"
    systemctl reload nginx
    echo "✓ Nginx 재시작 완료"
else
    echo "✗ Nginx 설정 오류"
    exit 1
fi

echo ""
echo "========================================"
echo "✓✓✓ 설정 완료! ✓✓✓"
echo "========================================"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📌 서비스별 접속 정보"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1️⃣  Nginx (정적 파일)"
echo "   URL:      http://www.litten7.com"
echo "   웹 루트:  /home/www/www/nginx"
echo ""
echo "2️⃣  Apache"
echo "   URL:      http://www.litten7.com:8080"
echo "   웹 루트:  /home/www/www/apache"
echo ""
echo "3️⃣  Tomcat (Spring Boot)"
echo "   URL:      http://www.litten7.com:8081"
echo "   웹 루트:  /home/backend/tomcat/webapps"
echo ""
echo "4️⃣  MariaDB"
echo "   접속:     203.245.29.74:3306"
echo "   계정:     root / mariadb"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 홈 디렉토리"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "www:      /home/www"
echo "  Nginx:  /home/www/www/nginx"
echo "  Apache: /home/www/www/apache"
echo ""
echo "backend:  /home/backend"
echo "  Tomcat: /home/backend/tomcat"
echo ""
echo "note:     /home/note"
echo "  Flutter: /home/note/flutter"
echo ""
echo "mariadb:  /home/mariadb"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
