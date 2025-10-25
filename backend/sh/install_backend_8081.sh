#!/bin/bash

set -e

BACKEND_USER="backend"
BACKEND_PASSWORD="zaq1!@2wsxN"
BACKEND_HOME="/home/backend"
JAVA_VERSION="17"
TOMCAT_VERSION="10.1.34"
TOMCAT_MAJOR="10"
TOMCAT_PORT="8081"
TOMCAT_DOWNLOAD_URL="https://dlcdn.apache.org/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"

echo "========================================"
echo "backend 계정 Java & Tomcat 설치"
echo "Tomcat 포트: ${TOMCAT_PORT}"
echo "========================================"
echo ""

echo "[1/5] backend 계정 생성 중..."

if id "$BACKEND_USER" &>/dev/null; then
    echo "✓ backend 계정이 이미 존재합니다."
else
    useradd -m -s /bin/bash -c "Backend Service Account" "$BACKEND_USER"
    echo "$BACKEND_USER:$BACKEND_PASSWORD" | chpasswd
    echo "✓ backend 계정 생성 완료"
fi

echo ""
echo "[2/5] Java ${JAVA_VERSION} 설치 중..."

if ! command -v java &> /dev/null; then
    apt update
    DEBIAN_FRONTEND=noninteractive apt install -y openjdk-${JAVA_VERSION}-jdk
    echo "✓ Java 설치 완료"
else
    echo "✓ Java가 이미 설치되어 있습니다."
fi

java -version
echo ""

echo "[3/5] Tomcat ${TOMCAT_VERSION} 다운로드 중..."

cd /tmp
rm -f apache-tomcat-${TOMCAT_VERSION}.tar.gz

wget --progress=bar:force:noscroll "$TOMCAT_DOWNLOAD_URL"

echo "✓ Tomcat 다운로드 완료"
echo ""

echo "[4/5] Tomcat 압축 해제 및 설정 중..."

if [ -d "$BACKEND_HOME/tomcat" ]; then
    mv "$BACKEND_HOME/tomcat" "$BACKEND_HOME/tomcat.backup.$(date +%Y%m%d_%H%M%S)"
fi

tar -xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz -C $BACKEND_HOME

ln -sf $BACKEND_HOME/apache-tomcat-${TOMCAT_VERSION} $BACKEND_HOME/tomcat

chown -R $BACKEND_USER:$BACKEND_USER $BACKEND_HOME/apache-tomcat-${TOMCAT_VERSION}
chown -h $BACKEND_USER:$BACKEND_USER $BACKEND_HOME/tomcat

chmod +x $BACKEND_HOME/tomcat/bin/*.sh

# Tomcat 포트 변경 (8080 -> 8081)
echo "Tomcat 포트를 ${TOMCAT_PORT}로 변경 중..."
sed -i "s/port=\"8080\"/port=\"${TOMCAT_PORT}\"/" $BACKEND_HOME/tomcat/conf/server.xml

echo "✓ Tomcat 설치 완료 (포트: ${TOMCAT_PORT})"
echo ""

echo "[5/5] 환경 변수 설정 중..."

if ! grep -q "JAVA_HOME" "$BACKEND_HOME/.bashrc"; then
    cat >> $BACKEND_HOME/.bashrc << 'BASHRC_EOF'

# Java Home
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# Tomcat Home
export CATALINA_HOME=$HOME/tomcat
export PATH=$CATALINA_HOME/bin:$PATH
BASHRC_EOF
    chown $BACKEND_USER:$BACKEND_USER $BACKEND_HOME/.bashrc
fi

echo "✓ 환경 변수 설정 완료"
echo ""

echo "Tomcat systemd 서비스 생성 중..."

cat > /etc/systemd/system/tomcat.service << SYSTEMD_EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

User=$BACKEND_USER
Group=$BACKEND_USER

Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"
Environment="CATALINA_PID=$BACKEND_HOME/tomcat/temp/tomcat.pid"
Environment="CATALINA_HOME=$BACKEND_HOME/tomcat"
Environment="CATALINA_BASE=$BACKEND_HOME/tomcat"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"

ExecStart=$BACKEND_HOME/tomcat/bin/startup.sh
ExecStop=$BACKEND_HOME/tomcat/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

systemctl daemon-reload

echo "✓ Tomcat 서비스 생성 완료"
echo ""

rm -f /tmp/apache-tomcat-${TOMCAT_VERSION}.tar.gz

echo "========================================"
echo "✓✓✓ 설치 완료! ✓✓✓"
echo "========================================"
echo ""
echo "계정: backend / zaq1!@2wsxN"
echo ""
echo "Java:"
java -version 2>&1 | head -1
echo ""
echo "Tomcat:"
echo "  - 포트: ${TOMCAT_PORT}"
echo "  - 경로: $BACKEND_HOME/tomcat"
echo ""
echo "시작: systemctl start tomcat"
echo "접속: http://203.245.29.74:${TOMCAT_PORT}"
echo ""
echo "========================================"
