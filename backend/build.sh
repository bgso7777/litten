#!/usr/bin/env bash
#
# litten backend 전용 빌드 스크립트.
#
# 목적: 이 맥북의 전역 java(현재 JDK 25)는 그대로 두고, 이 프로젝트를 빌드할 때만
#       JDK 17을 사용한다. (서버/프로젝트 타겟 = Java 17)
#
# 사용법:
#   ./build.sh clean package -DskipTests      # WAR 빌드
#   ./build.sh -version                       # Maven/자바 버전 확인
#
set -euo pipefail

# Homebrew keg-only openjdk@17 경로 (전역 기본값이 아니라 이 스크립트에서만 사용).
JAVA17_HOME="$(/opt/homebrew/bin/brew --prefix openjdk@17 2>/dev/null)/libexec/openjdk.jdk/Contents/Home"

if [ ! -x "$JAVA17_HOME/bin/java" ]; then
  echo "❌ JDK 17을 찾을 수 없습니다. 'brew install openjdk@17' 후 다시 시도하세요." >&2
  exit 1
fi

export JAVA_HOME="$JAVA17_HOME"
export PATH="$JAVA_HOME/bin:$PATH"

cd "$(dirname "$0")"

echo "▶ 이 빌드에서만 사용할 JAVA_HOME: $JAVA_HOME"
java -version
echo "▶ mvn $*"
exec mvn "$@"
