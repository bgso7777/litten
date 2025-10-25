#!/bin/bash

set -e

WWW_USER="www"
APACHE_ROOT="/home/www/www/apache"

echo "========================================"
echo "Apache 권한 문제 해결"
echo "========================================"
echo ""

echo "[1/3] 디렉토리 권한 설정 중..."

# /home/www 디렉토리에 실행 권한 부여 (Apache가 접근 가능하도록)
chmod 755 /home/www
chmod 755 /home/www/www
chmod 755 $APACHE_ROOT

# 파일 권한 설정
chmod 644 $APACHE_ROOT/index.html

# 소유권 확인
chown -R $WWW_USER:$WWW_USER /home/www/www

echo "✓ 권한 설정 완료"
echo ""

echo "[2/3] Apache 사용자 확인 및 설정..."

# Apache가 실행되는 사용자 확인
APACHE_USER=$(ps aux | grep apache2 | grep -v grep | head -1 | awk '{print $1}')
echo "Apache 실행 사용자: $APACHE_USER"

# www-data 그룹에 www 사용자 추가
if ! groups $WWW_USER | grep -q www-data; then
    usermod -aG www-data $WWW_USER
    echo "✓ www 사용자를 www-data 그룹에 추가"
fi

# 또는 Apache 실행 사용자를 www 그룹에 추가
if ! groups www-data | grep -q $WWW_USER; then
    usermod -aG $WWW_USER www-data
    echo "✓ www-data를 www 그룹에 추가"
fi

echo ""

echo "[3/3] Apache 재시작..."

systemctl restart apache2

echo "✓ Apache 재시작 완료"
echo ""

echo "========================================"
echo "✓✓✓ 권한 수정 완료! ✓✓✓"
echo "========================================"
echo ""
echo "디렉토리 권한:"
ls -la /home/www
echo ""
ls -la /home/www/www
echo ""
ls -la $APACHE_ROOT
echo ""
echo "접속 테스트:"
echo "  http://203.245.29.74"
echo ""
echo "========================================"
