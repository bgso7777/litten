#!/bin/bash

set -e

MARIADB_ROOT_PASSWORD="zaq1!@2wsxN"
MARIADB_USER="mariadb"

echo "========================================"
echo "MariaDB 3306 포트 오픈 설정"
echo "========================================"
echo ""

echo "[1/4] 방화벽 포트 오픈 중..."

# ufw 방화벽
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(ufw status | head -1)
    echo "UFW 상태: $UFW_STATUS"

    if echo "$UFW_STATUS" | grep -q "active"; then
        ufw allow 3306/tcp
        echo "✓ UFW 3306 포트 오픈 완료"
    fi
fi

# iptables
if command -v iptables &> /dev/null; then
    if ! iptables -L INPUT -n | grep -q "3306"; then
        iptables -I INPUT -p tcp --dport 3306 -j ACCEPT
        echo "✓ iptables 3306 포트 오픈 완료"
    fi
fi

echo ""
echo "[2/4] MariaDB 원격 접속 설정 중..."

MARIADB_CONF="/etc/mysql/mariadb.conf.d/50-server.cnf"
MYSQL_CONF="/etc/mysql/mysql.conf.d/mysqld.cnf"

if [ -f "$MARIADB_CONF" ]; then
    CONF_FILE="$MARIADB_CONF"
elif [ -f "$MYSQL_CONF" ]; then
    CONF_FILE="$MYSQL_CONF"
else
    CONF_FILE="/etc/mysql/my.cnf"
fi

echo "설정 파일: $CONF_FILE"
cp "$CONF_FILE" "${CONF_FILE}.backup"

if grep -q "^bind-address" "$CONF_FILE"; then
    sed -i 's/^bind-address.*/bind-address = 0.0.0.0/' "$CONF_FILE"
elif grep -q "^#bind-address" "$CONF_FILE"; then
    sed -i 's/^#bind-address.*/bind-address = 0.0.0.0/' "$CONF_FILE"
else
    sed -i '/\[mysqld\]/a bind-address = 0.0.0.0' "$CONF_FILE"
fi

echo "✓ bind-address 0.0.0.0 설정 완료"
echo ""

echo "[3/4] MariaDB 원격 사용자 권한 설정 중..."

mysql -uroot -p"${MARIADB_ROOT_PASSWORD}" << MYSQL_EOF
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO '${MARIADB_USER}'@'%' WITH GRANT OPTION;

FLUSH PRIVILEGES;

SELECT User, Host FROM mysql.user WHERE User IN ('root', '${MARIADB_USER}');
MYSQL_EOF

echo "✓ 원격 접속 권한 설정 완료"
echo ""

echo "[4/4] MariaDB 재시작 중..."

systemctl restart mariadb

echo "✓ MariaDB 재시작 완료"
echo ""

echo "MariaDB 포트 리스닝 확인..."
netstat -tlnp 2>/dev/null | grep 3306 || ss -tlnp | grep 3306

echo ""
echo "========================================"
echo "✓✓✓ 설정 완료! ✓✓✓"
echo "========================================"
echo ""
echo "MariaDB 원격 접속 정보:"
echo "  호스트: 203.245.29.74"
echo "  포트: 3306"
echo "  사용자: root 또는 mariadb"
echo "  비밀번호: ${MARIADB_ROOT_PASSWORD}"
echo ""
echo "접속 테스트:"
echo "  mysql -h 203.245.29.74 -P 3306 -uroot -p${MARIADB_ROOT_PASSWORD}"
echo ""
echo "⚠ 보안 주의: 모든 IP에서 접속 가능합니다"
echo ""
echo "========================================"
