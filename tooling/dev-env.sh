#!/usr/bin/env bash
# Load the repository's standard development toolchain into the current shell.
# Usage: source tooling/dev-env.sh

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Please source this file: source tooling/dev-env.sh" >&2
  exit 2
fi

_SOC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ANDROID_HOME="${ANDROID_HOME:-${HOME}/Android/Sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME}}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${_SOC_ROOT}/.tools/flutter-config}"
export PUB_CACHE="${PUB_CACHE:-${_SOC_ROOT}/.tools/pub-cache}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-${_SOC_ROOT}/.tools/gradle}"
export SOC_TOOL_HOME="${SOC_TOOL_HOME:-${_SOC_ROOT}/.tools/home}"
mkdir -p "${SOC_TOOL_HOME}" "${XDG_CONFIG_HOME}" "${PUB_CACHE}" "${GRADLE_USER_HOME}"

_soc_append_gradle_proxy() {
  local scheme="$1"
  local proxy_url="$2"
  local endpoint host port
  endpoint="${proxy_url#http://}"
  endpoint="${endpoint#https://}"
  if [[ "${endpoint}" == *"@"* ]]; then
    return
  fi
  host="${endpoint%:*}"
  port="${endpoint##*:}"
  if [[ -n "${host}" && "${port}" =~ ^[0-9]+$ ]]; then
    GRADLE_OPTS="${GRADLE_OPTS:-} -D${scheme}.proxyHost=${host} -D${scheme}.proxyPort=${port}"
  fi
}

# Gradle runs on the JVM, which does not consistently honor HTTP_PROXY/HTTPS_PROXY.
# Derive JVM proxy properties from the current shell without recording a host in Git.
if [[ -n "${HTTP_PROXY:-}" ]]; then
  _soc_append_gradle_proxy http "${HTTP_PROXY}"
fi
if [[ -n "${HTTPS_PROXY:-}" ]]; then
  _soc_append_gradle_proxy https "${HTTPS_PROXY}"
fi
if [[ -n "${HTTP_PROXY:-}" || -n "${HTTPS_PROXY:-}" ]]; then
  # Some local HTTP proxies close Java 21 TLS 1.3 handshakes intermittently.
  # Maven Central and Google Maven both support TLS 1.2.
  GRADLE_OPTS="${GRADLE_OPTS:-} -Dhttps.protocols=TLSv1.2 -Djdk.tls.client.protocols=TLSv1.2 -Dorg.gradle.internal.http.connectionTimeout=120000 -Dorg.gradle.internal.http.socketTimeout=120000"
fi
export GRADLE_OPTS
unset -f _soc_append_gradle_proxy
if [[ -d "${_SOC_ROOT}/.tools/lib" ]]; then
  export LD_LIBRARY_PATH="${_SOC_ROOT}/.tools/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
fi

if [[ -x "${_SOC_ROOT}/.tools/flutter/bin/flutter" ]]; then
  export FLUTTER_ROOT="${_SOC_ROOT}/.tools/flutter"
  export PATH="${FLUTTER_ROOT}/bin:${FLUTTER_ROOT}/bin/cache/dart-sdk/bin:${PATH}"

  # Flutter/Dart persist telemetry state under HOME. Keep it project-local.
  flutter() {
    HOME="${SOC_TOOL_HOME}" command "${FLUTTER_ROOT}/bin/flutter" "$@"
  }
  dart() {
    HOME="${SOC_TOOL_HOME}" command "${FLUTTER_ROOT}/bin/dart" "$@"
  }
fi

if [[ -x "${_SOC_ROOT}/.tools/jdk/bin/javac" ]]; then
  export JAVA_HOME="${_SOC_ROOT}/.tools/jdk"
  export PATH="${JAVA_HOME}/bin:${PATH}"
fi

export PATH="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/emulator:${ANDROID_SDK_ROOT}/build-tools/36.1.0:${PATH}"
unset _SOC_ROOT
