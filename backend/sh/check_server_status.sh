#!/bin/bash

echo "========================================"
echo "서버 상태 진단"
echo "========================================"
echo ""

echo "[1] Tomcat 서비스 상태 확인"
echo "----------------------------------------"
systemctl status tomcat --no-pager || echo "Tomcat 서비스 없음"
echo ""

echo "[2] Tomcat 프로세스 확인"
echo "----------------------------------------"
ps aux | grep tomcat | grep -v grep || echo "Tomcat 프로세스 없음"
echo ""

echo "[3] 포트 리스닝 확인"
echo "----------------------------------------"
echo "8081 포트 (Tomcat):"
netstat -tlnp 2>/dev/null | grep 8081 || ss -tlnp | grep 8081 || echo "8081 포트가 열려있지 않음"
echo ""

echo "[4] Tomcat webapps 디렉토리 확인"
echo "----------------------------------------"
ls -la /home/backend/tomcat/webapps/ 2>/dev/null || echo "webapps 디렉토리 없음"
echo ""

echo "[5] Tomcat 로그 확인 (마지막 30줄)"
echo "----------------------------------------"
tail -30 /home/backend/tomcat/logs/catalina.out 2>/dev/null || echo "로그 파일 없음"
echo ""

echo "[6] Nginx 프록시 설정 확인"
echo "----------------------------------------"
cat /etc/nginx/sites-enabled/tomcat-proxy 2>/dev/null || echo "Nginx 설정 없음"
echo ""

echo "[7] 로컬에서 Tomcat 접속 테스트"
echo "----------------------------------------"
curl -I http://localhost:8081 2>/dev/null || echo "Tomcat 접속 실패"
echo ""

echo "[8] 도메인 확인"
echo "----------------------------------------"
echo "www.litten7.com 해석:"
nslookup www.litten7.com || dig www.litten7.com || echo "DNS 조회 실패"
echo ""

echo "========================================"
echo "진단 완료"
echo "========================================"
