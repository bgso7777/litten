#!/bin/bash

set -e

WWW_USER="www"
WWW_PASSWORD="zaq1!@2wsxN"
WWW_HOME="/home/www"

echo "========================================"
echo "웹 서버 설치 시작"
echo "========================================"
echo ""

echo "[1/5] www 사용자 계정 생성 중..."
echo "----------------------------------------"

if id "$WWW_USER" &>/dev/null; then
    echo "✓ www 계정이 이미 존재합니다."
else
    useradd -m -s /bin/bash -c "Web Server Account" "$WWW_USER"
    echo "$WWW_USER:$WWW_PASSWORD" | chpasswd
    echo "✓ www 계정 생성 완료"
fi

echo "  - 사용자명: $WWW_USER"
echo "  - 비밀번호: $WWW_PASSWORD"
echo "  - 홈 디렉토리: $WWW_HOME"
echo ""

echo "[2/5] Nginx 설치 중..."
echo "----------------------------------------"

apt update
DEBIAN_FRONTEND=noninteractive apt install -y nginx

systemctl start nginx
systemctl enable nginx

echo "✓ Nginx 설치 완료"
nginx -v
echo ""

echo "[3/5] Apache 설치 중..."
echo "----------------------------------------"

DEBIAN_FRONTEND=noninteractive apt install -y apache2

sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf
sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/000-default.conf

systemctl restart apache2
systemctl enable apache2

echo "✓ Apache 설치 완료"
apache2 -v
echo ""

echo "[4/5] www 계정 웹 디렉토리 설정 중..."
echo "----------------------------------------"

mkdir -p $WWW_HOME/www/nginx
echo "<h1>Nginx - Welcome to Litten Web Server</h1>" > $WWW_HOME/www/nginx/index.html

mkdir -p $WWW_HOME/www/apache
echo "<h1>Apache - Welcome to Litten Web Server</h1>" > $WWW_HOME/www/apache/index.html

chown -R $WWW_USER:$WWW_USER $WWW_HOME/www
chmod -R 755 $WWW_HOME/www

echo "✓ 웹 디렉토리 생성 완료"
echo "  - Nginx 웹 루트: $WWW_HOME/www/nginx"
echo "  - Apache 웹 루트: $WWW_HOME/www/apache"
echo ""

echo "[5/5] Nginx 기본 설정 중..."
echo "----------------------------------------"

cat > /etc/nginx/sites-available/www << 'NGINX_CONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /home/www/www/nginx;
    index index.html index.htm;

    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX_CONF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/www /etc/nginx/sites-enabled/

nginx -t
systemctl reload nginx

echo "✓ Nginx 설정 완료"
echo ""

echo "========================================"
echo "✓✓✓ 웹 서버 설치 완료! ✓✓✓"
echo "========================================"
echo ""
echo "계정 정보:"
echo "  - 사용자명: $WWW_USER"
echo "  - 비밀번호: $WWW_PASSWORD"
echo "  - 홈 디렉토리: $WWW_HOME"
echo ""
echo "웹 서버 정보:"
echo ""
echo "Nginx:"
echo "  - 포트: 80"
echo "  - 웹 루트: $WWW_HOME/www/nginx"
echo "  - 테스트 URL: http://203.245.29.74"
echo ""
echo "Apache:"
echo "  - 포트: 8080"
echo "  - 웹 루트: $WWW_HOME/www/apache"
echo "  - 테스트 URL: http://203.245.29.74:8080"
echo ""
echo "========================================"
