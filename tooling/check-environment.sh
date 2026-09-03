#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "${ROOT}/tooling/dev-env.sh" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT}/tooling/dev-env.sh"
fi

failures=0
check_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf 'OK   %-18s %s\n' "$name" "$(command -v "$name")"
  else
    printf 'MISS %-18s\n' "$name"
    failures=$((failures + 1))
  fi
}

printf 'SOC-Shield development environment\n'
printf 'root: %s\n\n' "$ROOT"
check_command flutter
check_command dart
check_command java
check_command javac
check_command adb
check_command sdkmanager
check_command git
check_command node
check_command npm
check_command google-chrome

if [[ -f "${ROOT}/.tools/lib/libsqlite3.so" || -L "${ROOT}/.tools/lib/libsqlite3.so" ]]; then
  printf 'OK   %-18s %s\n' 'libsqlite3.so' "${ROOT}/.tools/lib/libsqlite3.so"
else
  printf 'MISS %-18s\n' 'libsqlite3.so (test)'
  failures=$((failures + 1))
fi

printf '\nVersions\n'
flutter --version 2>/dev/null | sed -n '1,3p' || true
dart --version 2>&1 || true
java -version 2>&1 | sed -n '1,2p' || true
javac -version 2>&1 || true
node --version 2>/dev/null || true
npm --version 2>/dev/null || true

require_version() {
  local label="$1"
  local actual="$2"
  local pattern="$3"
  if [[ "${actual}" == *"${pattern}"* ]]; then
    printf 'OK   %-18s %s\n' "${label}" "${pattern}"
  else
    printf 'MISS %-18s expected %s; got %s\n' "${label}" "${pattern}" "${actual:-<unavailable>}"
    failures=$((failures + 1))
  fi
}

printf '\nVersion baseline\n'
require_version 'Flutter' "$(flutter --version 2>/dev/null | sed -n '1p')" 'Flutter 3.44.2'
require_version 'Dart' "$(dart --version 2>&1)" 'Dart SDK version: 3.12.2'
require_version 'JDK' "$(javac -version 2>&1)" 'javac 21.'
require_version 'Node.js' "$(node --version 2>/dev/null)" 'v22.'

printf '\nAndroid SDK\n'
printf 'ANDROID_SDK_ROOT=%s\n' "${ANDROID_SDK_ROOT:-<unset>}"
if [[ -f "${ANDROID_SDK_ROOT:-}/platforms/android-36/android.jar" ]]; then
  printf 'OK   Android platform 36\n'
else
  printf 'MISS Android platform 36\n'
  failures=$((failures + 1))
fi
if [[ -x "${ANDROID_SDK_ROOT:-}/build-tools/36.1.0/aapt2" ]]; then
  printf 'OK   Android build-tools 36.1.0\n'
else
  printf 'MISS Android build-tools 36.1.0\n'
  failures=$((failures + 1))
fi
if [[ -f "${ANDROID_SDK_ROOT:-}/ndk/28.2.13676358/source.properties" ]]; then
  printf 'OK   Android NDK 28.2.13676358\n'
else
  printf 'MISS Android NDK 28.2.13676358\n'
  failures=$((failures + 1))
fi
if [[ -x "${ANDROID_SDK_ROOT:-}/cmake/3.22.1/bin/cmake" ]]; then
  printf 'OK   Android CMake 3.22.1\n'
else
  printf 'MISS Android CMake 3.22.1\n'
  failures=$((failures + 1))
fi

printf '\nResult: '
if (( failures == 0 )); then
  printf 'ready\n'
else
  printf '%d required check(s) missing\n' "$failures"
fi
exit "$failures"
