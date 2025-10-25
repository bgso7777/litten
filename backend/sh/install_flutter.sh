#!/bin/bash

set -e

NOTE_USER="note"
NOTE_PASSWORD="zaq1!@2wsxN"
NOTE_HOME="/home/note"
FLUTTER_INSTALL_DIR="$NOTE_HOME/flutter"

echo "========================================"
echo "note 계정 Git & Flutter 설치 시작"
echo "========================================"
echo ""

echo "[1/6] note 사용자 계정 생성 중..."
echo "----------------------------------------"

if id "$NOTE_USER" &>/dev/null; then
    echo "✓ note 계정이 이미 존재합니다."
else
    useradd -m -s /bin/bash -c "Flutter Web Account" "$NOTE_USER"
    echo "$NOTE_USER:$NOTE_PASSWORD" | chpasswd
    echo "✓ note 계정 생성 완료"
fi

echo "  - 사용자명: $NOTE_USER"
echo "  - 비밀번호: $NOTE_PASSWORD"
echo "  - 홈 디렉토리: $NOTE_HOME"
echo ""

echo "[2/6] 필수 패키지 설치 중..."
echo "----------------------------------------"

apt update
DEBIAN_FRONTEND=noninteractive apt install -y \
    git \
    curl \
    wget \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev

echo "✓ 필수 패키지 설치 완료"
git --version
echo ""

echo "[3/6] Flutter SDK 다운로드 중..."
echo "----------------------------------------"

cd /tmp

if [ -f "flutter_linux.tar.xz" ]; then
    rm -f flutter_linux.tar.xz
fi

echo "Flutter SDK 다운로드 중... (시간이 걸릴 수 있습니다)"
wget -q --show-progress https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_stable.tar.xz -O flutter_linux.tar.xz

echo "✓ Flutter SDK 다운로드 완료"
ls -lh flutter_linux.tar.xz
echo ""

echo "[4/6] Flutter SDK 압축 해제 중..."
echo "----------------------------------------"

if [ -d "$FLUTTER_INSTALL_DIR" ]; then
    echo "기존 Flutter 디렉토리 백업 중..."
    mv "$FLUTTER_INSTALL_DIR" "$FLUTTER_INSTALL_DIR.backup.$(date +%Y%m%d_%H%M%S)"
fi

tar -xf flutter_linux.tar.xz -C $NOTE_HOME

chown -R $NOTE_USER:$NOTE_USER $FLUTTER_INSTALL_DIR

echo "✓ Flutter SDK 압축 해제 완료"
echo "  - 설치 경로: $FLUTTER_INSTALL_DIR"
echo ""

echo "[5/6] 환경 변수 설정 중..."
echo "----------------------------------------"

cat >> $NOTE_HOME/.bashrc << 'BASHRC_EOF'

# Flutter SDK 경로
export PATH="$HOME/flutter/bin:$PATH"

# Flutter 웹 개발 환경
export CHROME_EXECUTABLE=/usr/bin/google-chrome-stable
BASHRC_EOF

chown $NOTE_USER:$NOTE_USER $NOTE_HOME/.bashrc

echo "✓ 환경 변수 설정 완료"
echo ""

echo "[6/6] Flutter 초기 설정 중..."
echo "----------------------------------------"

su - $NOTE_USER -c "flutter --version"
su - $NOTE_USER -c "flutter config --no-analytics"
su - $NOTE_USER -c "flutter config --enable-web"
su - $NOTE_USER -c "flutter precache --web"

echo "✓ Flutter 초기 설정 완료"
echo ""

echo "임시 파일 정리 중..."
rm -f /tmp/flutter_linux.tar.xz

echo "========================================"
echo "✓✓✓ 설치 완료! ✓✓✓"
echo "========================================"
echo ""
echo "계정 정보:"
echo "  - 사용자명: $NOTE_USER"
echo "  - 비밀번호: $NOTE_PASSWORD"
echo "  - 홈 디렉토리: $NOTE_HOME"
echo ""
echo "설치된 도구:"
echo ""
echo "Git:"
su - $NOTE_USER -c "git --version"
echo ""
echo "Flutter:"
su - $NOTE_USER -c "flutter --version" | head -1
echo "  - 설치 경로: $FLUTTER_INSTALL_DIR"
echo "  - Web 지원: 활성화됨"
echo ""
echo "사용 방법:"
echo ""
echo "# note 계정으로 전환"
echo "su - note"
echo ""
echo "# Flutter 버전 확인"
echo "flutter --version"
echo ""
echo "# Flutter doctor 실행"
echo "flutter doctor"
echo ""
echo "# Flutter 웹 프로젝트 빌드"
echo "flutter build web"
echo ""
echo "========================================"
