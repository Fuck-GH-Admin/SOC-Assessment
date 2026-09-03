#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${ROOT}/.tools"
FLUTTER_VERSION="3.44.2"
FLUTTER_ARCHIVE="${TOOLS}/cache/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_SHA256="b0de1d19754688ec6769c9a067db3b0594479d3d767f971bfecfc132904c8d5e"
JDK_ARCHIVE="${TOOLS}/cache/OpenJDK21U-jdk_x64_linux_hotspot_21.0.12_8.tar.gz"
JDK_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12%2B8/OpenJDK21U-jdk_x64_linux_hotspot_21.0.12_8.tar.gz"
JDK_SHA256="e4446ff06a276155697597cc0f1b15da004ff083f4964a35271ecee567177370"

mkdir -p "${TOOLS}/cache"

verify_sha256() {
  local archive="$1"
  local expected="$2"
  local actual
  actual="$(sha256sum "${archive}" | awk '{print $1}')"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "Checksum verification failed: ${archive}" >&2
    echo "Expected: ${expected}" >&2
    echo "Actual:   ${actual}" >&2
    exit 1
  fi
}

if [[ ! -x "${TOOLS}/flutter/bin/flutter" ]]; then
  if [[ ! -f "${FLUTTER_ARCHIVE}" ]]; then
    echo "Downloading Flutter ${FLUTTER_VERSION}..."
    curl -L --fail --retry 3 --retry-delay 2 -o "${FLUTTER_ARCHIVE}" "${FLUTTER_URL}"
  fi
  verify_sha256 "${FLUTTER_ARCHIVE}" "${FLUTTER_SHA256}"
  echo "Extracting Flutter ${FLUTTER_VERSION}..."
  tar -xJf "${FLUTTER_ARCHIVE}" -C "${TOOLS}"
fi

if [[ ! -x "${TOOLS}/jdk/bin/javac" ]]; then
  if [[ ! -f "${JDK_ARCHIVE}" ]]; then
    echo "Downloading Temurin JDK 21.0.12..."
    curl -L --fail --retry 3 --retry-delay 2 -o "${JDK_ARCHIVE}" "${JDK_URL}"
  fi
  verify_sha256 "${JDK_ARCHIVE}" "${JDK_SHA256}"
  echo "Extracting JDK 21.0.12..."
  jdk_dir="$(tar -tzf "${JDK_ARCHIVE}" | sed -n '1s#/.*##p')"
  tar -xzf "${JDK_ARCHIVE}" -C "${TOOLS}"
  mv "${TOOLS}/${jdk_dir}" "${TOOLS}/jdk"
fi

sqlite_runtime="$(ldconfig -p 2>/dev/null | awk '/libsqlite3\.so\.0 / {print $NF; exit}')"
if [[ -z "${sqlite_runtime}" || ! -f "${sqlite_runtime}" ]]; then
  echo "A system libsqlite3.so.0 runtime is required for Linux Dart FFI tests." >&2
  exit 1
fi
mkdir -p "${TOOLS}/lib"
ln -sfn "${sqlite_runtime}" "${TOOLS}/lib/libsqlite3.so"

if [[ ! -x "${TOOLS}/jdk/bin/javac" ]]; then
  echo "JDK was not installed at ${TOOLS}/jdk" >&2
  exit 1
fi

if [[ ! -x "${TOOLS}/flutter/bin/flutter" ]]; then
  echo "Flutter SDK was not installed at ${TOOLS}/flutter" >&2
  exit 1
fi

echo "Flutter SDK ready:"
HOME="${TOOLS}/home" XDG_CONFIG_HOME="${TOOLS}/flutter-config" PUB_CACHE="${TOOLS}/pub-cache" GRADLE_USER_HOME="${TOOLS}/gradle" "${TOOLS}/flutter/bin/flutter" --disable-analytics
HOME="${TOOLS}/home" XDG_CONFIG_HOME="${TOOLS}/flutter-config" PUB_CACHE="${TOOLS}/pub-cache" GRADLE_USER_HOME="${TOOLS}/gradle" "${TOOLS}/flutter/bin/flutter" --version | sed -n '1,3p'
echo "JDK ready:"
"${TOOLS}/jdk/bin/java" -version 2>&1 | sed -n '1,2p'
echo "SQLite test library: ${sqlite_runtime}"
echo
echo "Next: source tooling/dev-env.sh && bash tooling/check-environment.sh"
