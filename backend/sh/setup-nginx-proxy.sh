#!/bin/bash

# Nginx 리버스 프록시 설정 스크립트
# 사용법: sudo ./setup-nginx-proxy.sh

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# root 권한 확인
if [ "$EUID" -ne 0 ]; then
    log_error "이 스크립트는 root 권한으로 실행해야 합니다."
    log_info "다음과 같이 실행하세요: sudo $0"
    exit 1
fi

# Nginx 설치 확인
if ! command -v nginx &> /dev/null; then
    log_error "Nginx가 설치되어 있지 않습니다."
    log_info "Nginx를 설치하시겠습니까? (y/n)"
    read -r answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        apt-get update
        apt-get install -y nginx
        log_info "Nginx가 설치되었습니다."
    else
        log_error "Nginx가 필요합니다. 종료합니다."
        exit 1
    fi
fi

# 설정 파일 경로 결정
if [ -d "/etc/nginx/sites-available" ]; then
    # Ubuntu/Debian
    SITES_AVAILABLE="/etc/nginx/sites-available"
    SITES_ENABLED="/etc/nginx/sites-enabled"
    CONFIG_FILE="$SITES_AVAILABLE/litten7.com"
    USE_SITES_ENABLED=true
elif [ -d "/etc/nginx/conf.d" ]; then
    # CentOS/RHEL
    SITES_AVAILABLE="/etc/nginx/conf.d"
    CONFIG_FILE="$SITES_AVAILABLE/litten7.com.conf"
    USE_SITES_ENABLED=false
else
    log_error "Nginx 설정 디렉토리를 찾을 수 없습니다."
    exit 1
fi

log_info "Nginx 설정 파일 생성: $CONFIG_FILE"

# 기존 설정 백업
if [ -f "$CONFIG_FILE" ]; then
    BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    log_warn "기존 설정 파일이 존재합니다. 백업 생성: $BACKUP_FILE"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
fi

# Nginx 설정 파일 생성
cat > "$CONFIG_FILE" << 'EOF'
server {
    listen 80;
    server_name www.litten7.com litten7.com;

    # 로그 설정
    access_log /var/log/nginx/litten7_access.log;
    error_log /var/log/nginx/litten7_error.log;

    # /litten 경로 프록시
    location /litten {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket 지원
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # 타임아웃 설정
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # 버퍼 설정
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    # 루트 경로 (필요시 수정)
    location / {
        root /var/www/html;
        index index.html index.htm;
    }
}
EOF

log_info "Nginx 설정 파일이 생성되었습니다."

# sites-enabled 심볼릭 링크 생성 (Ubuntu/Debian)
if [ "$USE_SITES_ENABLED" = true ]; then
    LINK_FILE="$SITES_ENABLED/litten7.com"
    if [ -L "$LINK_FILE" ] || [ -f "$LINK_FILE" ]; then
        log_warn "기존 심볼릭 링크 제거: $LINK_FILE"
        rm -f "$LINK_FILE"
    fi
    ln -s "$CONFIG_FILE" "$LINK_FILE"
    log_info "심볼릭 링크 생성: $LINK_FILE -> $CONFIG_FILE"
fi

# default 설정 비활성화 (필요시)
if [ "$USE_SITES_ENABLED" = true ] && [ -L "$SITES_ENABLED/default" ]; then
    log_warn "default 사이트를 비활성화하시겠습니까? (y/n)"
    read -r answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        rm -f "$SITES_ENABLED/default"
        log_info "default 사이트가 비활성화되었습니다."
    fi
fi

# Nginx 설정 테스트
log_info "Nginx 설정 테스트 중..."
if nginx -t; then
    log_info "Nginx 설정이 올바릅니다."
else
    log_error "Nginx 설정에 오류가 있습니다. 백업 파일로 복원하세요."
    exit 1
fi

# Nginx 재시작
log_info "Nginx를 재시작하시겠습니까? (y/n)"
read -r answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    if systemctl restart nginx; then
        log_info "Nginx가 성공적으로 재시작되었습니다."
    else
        log_error "Nginx 재시작에 실패했습니다."
        exit 1
    fi
else
    log_warn "Nginx를 재시작하지 않았습니다. 수동으로 재시작하세요:"
    log_warn "  sudo systemctl restart nginx"
fi

# 상태 확인
log_info "Nginx 상태 확인:"
systemctl status nginx --no-pager | head -n 10

# 포트 8081 확인
log_info ""
log_info "포트 8081에서 실행 중인 서비스 확인:"
if ss -tlnp | grep :8081; then
    log_info "포트 8081에서 서비스가 실행 중입니다."
else
    log_warn "포트 8081에서 실행 중인 서비스가 없습니다."
    log_warn "백엔드 애플리케이션을 먼저 시작하세요."
fi

log_info ""
log_info "==============================================="
log_info "설정 완료!"
log_info "==============================================="
log_info "테스트: curl http://localhost/litten"
log_info "로그 확인: sudo tail -f /var/log/nginx/litten7_error.log"
log_info "==============================================="