#!/bin/bash

set -e

MARIADB_ROOT_PASSWORD="zaq1!@2wsxN"
MARIADB_USER="mariadb"
MARIADB_USER_PASSWORD="zaq1!@2wsxN"

echo "========================================"
echo "MariaDB 완전 자동 설치 시작"
echo "========================================"
echo ""

echo "[1/3] MariaDB 서버 설치 중..."
echo "----------------------------------------"

apt update
DEBIAN_FRONTEND=noninteractive apt install -y mariadb-server mariadb-client

systemctl start mariadb
systemctl enable mariadb

echo "✓ MariaDB 설치 완료"
mysql --version
echo ""

echo "[2/3] MariaDB 보안 설정 중..."
echo "----------------------------------------"

mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';" 2>/dev/null || \
mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${MARIADB_ROOT_PASSWORD}');"

mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='';"
mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS test;"
mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

echo "✓ 보안 설정 완료"
echo ""

echo "[3/3] mariadb 사용자 계정 생성 중..."
echo "----------------------------------------"

if id "$MARIADB_USER" &>/dev/null; then
    echo "✓ mariadb 리눅스 계정이 이미 존재합니다."
else
    useradd -m -s /bin/bash -c "MariaDB User Account" "$MARIADB_USER"
    echo "$MARIADB_USER:$MARIADB_USER_PASSWORD" | chpasswd
    echo "✓ mariadb 리눅스 계정 생성 완료"
fi

mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "DROP USER IF EXISTS '${MARIADB_USER}'@'localhost';"
mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "CREATE USER '${MARIADB_USER}'@'localhost' IDENTIFIED BY '${MARIADB_USER_PASSWORD}';"
mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON *.* TO '${MARIADB_USER}'@'localhost' WITH GRANT OPTION;"
mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

echo "✓ mariadb 데이터베이스 사용자 생성 완료"
echo ""

echo "========================================"
echo "✓✓✓ 설치 완료! ✓✓✓"
echo "========================================"
echo ""
echo "계정 정보"
echo "----------------------------------------"
echo "1. MariaDB root: root / ${MARIADB_ROOT_PASSWORD}"
echo "2. 리눅스 계정: ${MARIADB_USER} / ${MARIADB_USER_PASSWORD}"
echo "3. MariaDB 계정: ${MARIADB_USER}@localhost / ${MARIADB_USER_PASSWORD}"
echo ""
echo "접속 테스트: mysql -umariadb -p${MARIADB_USER_PASSWORD}"
echo "========================================"
