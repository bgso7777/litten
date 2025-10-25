#!/bin/bash

set -e

WWW_USER="www"
NEW_DOCUMENT_ROOT="/home/www/www/apache"

echo "========================================"
echo "Apache DocumentRoot 변경"
echo "========================================"
echo ""
echo "기존: /var/www/html"
echo "변경: $NEW_DOCUMENT_ROOT"
echo ""

echo "[1/4] 디렉토리 생성 및 권한 설정 중..."

mkdir -p $NEW_DOCUMENT_ROOT

cat > $NEW_DOCUMENT_ROOT/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Litten - Apache Web Server</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 40px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 20px;
            backdrop-filter: blur(10px);
        }
        h1 { font-size: 3em; margin: 0; }
        p { font-size: 1.2em; margin: 20px 0; }
        .info { font-size: 0.9em; opacity: 0.8; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Litten Web Server</h1>
        <p>Apache is running successfully!</p>
        <div class="info">
            <p>Document Root: /home/www/www/apache</p>
            <p>Port: 8080 (via Nginx :80)</p>
        </div>
    </div>
</body>
</html>
HTML_EOF

chown -R $WWW_USER:$WWW_USER /home/www/www
chmod -R 755 /home/www/www

echo "✓ 디렉토리 생성 완료"
echo ""

echo "[2/4] Apache 설정 파일 변경 중..."

cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.backup

sed -i 's|^<Directory /var/www/>|#<Directory /var/www/>|' /etc/apache2/apache2.conf
sed -i '/^#<Directory \/var\/www\/>/,/^<\/Directory>/ s/^/#/' /etc/apache2/apache2.conf

if ! grep -q "<Directory $NEW_DOCUMENT_ROOT>" /etc/apache2/apache2.conf; then
    cat >> /etc/apache2/apache2.conf << APACHE_CONF

# Litten Web Server Document Root
<Directory $NEW_DOCUMENT_ROOT>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
APACHE_CONF
fi

echo "✓ apache2.conf 수정 완료"
echo ""

echo "[3/4] VirtualHost 설정 변경 중..."

cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.backup

sed -i "s|DocumentRoot /var/www/html|DocumentRoot $NEW_DOCUMENT_ROOT|" /etc/apache2/sites-available/000-default.conf

if ! grep -q "Listen 8080" /etc/apache2/ports.conf; then
    sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf
fi

sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/000-default.conf

echo "✓ VirtualHost 설정 완료"
echo ""

echo "[4/4] Apache 설정 테스트 및 재시작 중..."

apache2ctl configtest

if [ $? -eq 0 ]; then
    echo "✓ Apache 설정 테스트 통과"
    echo ""
    
    systemctl restart apache2
    
    echo "✓ Apache 재시작 완료"
else
    echo "✗ Apache 설정 오류"
    mv /etc/apache2/apache2.conf.backup /etc/apache2/apache2.conf
    mv /etc/apache2/sites-available/000-default.conf.backup /etc/apache2/sites-available/000-default.conf
    systemctl restart apache2
    exit 1
fi

echo ""
echo "========================================"
echo "✓✓✓ 설정 완료! ✓✓✓"
echo "========================================"
echo ""
echo "DocumentRoot 변경:"
echo "  기존: /var/www/html"
echo "  변경: $NEW_DOCUMENT_ROOT"
echo ""
echo "접속 테스트:"
echo "  http://203.245.29.74"
echo ""
echo "파일 업로드 위치:"
echo "  $NEW_DOCUMENT_ROOT"
echo ""
echo "========================================"
