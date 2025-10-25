#!/bin/bash

set -e

NOTE_USER="note"
NOTE_HOME="/home/note"
FLUTTER_DIR="$NOTE_HOME/flutter"
FLUTTER_VERSION="3.9.3"

echo "========================================"
echo "Flutter 3.9.3 설치"
echo "========================================"
echo ""

# note 계정 확인
if ! id "$NOTE_USER" &>/dev/null; then
    echo "note 계정 생성 중..."
    useradd -m -s /bin/bash "$NOTE_USER"
    echo "$NOTE_USER:zaq1!@2wsxN" | chpasswd
fi

# Git 설치 확인
if ! command -v git &> /dev/null; then
    echo "Git 설치 중..."
    apt update
    DEBIAN_FRONTEND=noninteractive apt install -y git curl wget unzip xz-utils
fi

# 기존 Flutter 삭제
if [ -d "$FLUTTER_DIR" ]; then
    rm -rf "$FLUTTER_DIR"
fi

# Flutter 3.9.3 클론
echo "Flutter 3.9.3 다운로드 중... (5-10분 소요)"
su - $NOTE_USER -c "git clone https://github.com/flutter/flutter.git -b 3.9.3 $FLUTTER_DIR"

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
su - $NOTE_USER -c "flutter --version"
su - $NOTE_USER -c "flutter config --no-analytics"
su - $NOTE_USER -c "flutter config --enable-web"
su - $NOTE_USER -c "flutter precache --web"

echo ""
echo "========================================"
echo "✓✓✓ Flutter 3.9.3 설치 완료! ✓✓✓"
echo "========================================"
echo ""
su - $NOTE_USER -c "flutter --version"
echo ""
echo "사용: su - note"
echo "========================================"
