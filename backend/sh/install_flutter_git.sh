#!/bin/bash

set -e

NOTE_USER="note"
NOTE_PASSWORD="zaq1!@2wsxN"
NOTE_HOME="/home/note"
FLUTTER_INSTALL_DIR="$NOTE_HOME/flutter"

echo "========================================"
echo "Flutter 설치 (Git 방식)"
echo "========================================"
echo ""

# note 계정 생성
if ! id "$NOTE_USER" &>/dev/null; then
    echo "note 계정 생성 중..."
    useradd -m -s /bin/bash -c "Flutter Web Account" "$NOTE_USER"
    echo "$NOTE_USER:$NOTE_PASSWORD" | chpasswd
    echo "✓ note 계정 생성 완료"
fi

# Git 설치
if ! command -v git &> /dev/null; then
    echo "Git 설치 중..."
    apt update
    DEBIAN_FRONTEND=noninteractive apt install -y git curl wget unzip xz-utils zip
    echo "✓ Git 설치 완료"
fi

# 기존 Flutter 디렉토리 백업
if [ -d "$FLUTTER_INSTALL_DIR" ]; then
    echo "기존 Flutter 디렉토리 백업 중..."
    mv "$FLUTTER_INSTALL_DIR" "$FLUTTER_INSTALL_DIR.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Git으로 Flutter 클론
echo ""
echo "Flutter SDK 다운로드 중 (Git Clone)..."
echo "이 작업은 5-10분 정도 걸립니다..."
echo ""

su - $NOTE_USER -c "git clone https://github.com/flutter/flutter.git -b stable $FLUTTER_INSTALL_DIR"

# 환경 변수 설정
if ! grep -q "flutter/bin" "$NOTE_HOME/.bashrc"; then
    cat >> $NOTE_HOME/.bashrc << 'BASHRC_EOF'

# Flutter SDK
export PATH="$HOME/flutter/bin:$PATH"
BASHRC_EOF
    chown $NOTE_USER:$NOTE_USER $NOTE_HOME/.bashrc
fi

# Flutter 초기 설정
echo ""
echo "Flutter 초기 설정 중..."
su - $NOTE_USER -c "export PATH=$FLUTTER_INSTALL_DIR/bin:\$PATH && flutter --version"
su - $NOTE_USER -c "export PATH=$FLUTTER_INSTALL_DIR/bin:\$PATH && flutter config --no-analytics"
su - $NOTE_USER -c "export PATH=$FLUTTER_INSTALL_DIR/bin:\$PATH && flutter config --enable-web"
su - $NOTE_USER -c "export PATH=$FLUTTER_INSTALL_DIR/bin:\$PATH && flutter precache --web"

echo ""
echo "========================================"
echo "✓✓✓ 설치 완료! ✓✓✓"
echo "========================================"
echo ""
echo "note 계정 정보:"
echo "  - 사용자명: note"
echo "  - 비밀번호: zaq1!@2wsxN"
echo ""
echo "설치 확인:"
su - $NOTE_USER -c "flutter --version"
echo ""
echo "사용 방법:"
echo "  su - note"
echo "  flutter doctor"
echo ""
echo "========================================"
