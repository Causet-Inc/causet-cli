#!/usr/bin/env bash
# Install Causet CLI + compiler from public GitHub Releases (Causet-Inc/causet-cli).
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Causet-Inc/causet-cli/main/install.sh | bash
#   CAUSET_VERSION=v1.0.2 curl -fsSL ... | bash
#
set -euo pipefail

REPO="${CAUSET_REPO:-Causet-Inc/causet-cli}"
INSTALL_DIR="${CAUSET_INSTALL_DIR:-${HOME}/.causet/bin}"
VERSION="${CAUSET_VERSION:-}"
VERIFY_CHECKSUMS="${CAUSET_VERIFY_CHECKSUMS:-1}"

die() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

detect_platform() {
  local raw_os raw_arch
  raw_os="$(uname -s)"
  raw_arch="$(uname -m)"

  case "$raw_os" in
    Darwin) OS=darwin ;;
    Linux)  OS=linux ;;
    *) die "unsupported OS: ${raw_os} (macOS and Linux only)" ;;
  esac

  case "$raw_arch" in
    x86_64|amd64)   ARCH=amd64 ;;
    arm64|aarch64)  ARCH=arm64 ;;
    *) die "unsupported CPU architecture: ${raw_arch}" ;;
  esac
}

download_url() {
  local asset=$1
  if [[ -n "$VERSION" ]]; then
    echo "https://github.com/${REPO}/releases/download/${VERSION}/${asset}"
  else
    echo "https://github.com/${REPO}/releases/latest/download/${asset}"
  fi
}

try_fetch() {
  local url=$1
  local dest=$2
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    die "curl or wget is required"
  fi
}

verify_checksum() {
  local asset=$1
  local file=$2
  [[ "$VERIFY_CHECKSUMS" == "1" ]] || return 0

  local checksums expected actual
  checksums="$(mktemp)"
  try_fetch "$(download_url checksums.txt)" "$checksums"
  expected="$(awk -v f="$asset" '$2 == f { print $1; exit }' "$checksums")"
  rm -f "$checksums"

  [[ -n "$expected" ]] || die "checksums.txt has no entry for ${asset}"

  if command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  elif command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  else
    echo "warning: no sha256 tool found; skipping checksum verification" >&2
    return 0
  fi

  [[ "$actual" == "$expected" ]] || die "checksum mismatch for ${asset}"
}

install_asset() {
  local asset=$1
  local dest_name=$2
  local url dest tmp
  url="$(download_url "$asset")"
  dest="${INSTALL_DIR}/${dest_name}"
  tmp="$(mktemp)"
  echo "Downloading ${asset}..."
  try_fetch "$url" "$tmp"
  verify_checksum "$asset" "$tmp"
  mkdir -p "$INSTALL_DIR"
  mv "$tmp" "$dest"
  chmod +x "$dest" 2>/dev/null || true
  echo "Installed ${dest}"
}

install_compiler_with_fallback() {
  local candidates=()
  local primary="causet-compiler-${OS}-${ARCH}"
  candidates+=("$primary")
  if [[ "$OS" == linux && "$ARCH" == arm64 ]]; then
    candidates+=("causet-compiler-linux-amd64")
  fi

  local asset url tmp dest
  for asset in "${candidates[@]}"; do
    url="$(download_url "$asset")"
    tmp="$(mktemp)"
    if try_fetch "$url" "$tmp" 2>/dev/null; then
      verify_checksum "$asset" "$tmp"
      dest="${INSTALL_DIR}/causet-compiler"
      mkdir -p "$INSTALL_DIR"
      mv "$tmp" "$dest"
      chmod +x "$dest" 2>/dev/null || true
      echo "Installed ${dest} (from ${asset})"
      if [[ "$asset" != "$primary" ]]; then
        echo "note: ${primary} is not published yet; using ${asset}" >&2
      fi
      return 0
    fi
    rm -f "$tmp"
  done
  die "could not download compiler for ${OS}/${ARCH}"
}

main() {
  require_cmd uname
  detect_platform

  local cli_asset="causet-${OS}-${ARCH}"
  install_asset "$cli_asset" "causet"
  install_compiler_with_fallback

  cat <<EOF

Causet CLI installed to ${INSTALL_DIR}

Add to your shell profile:

  export PATH="${INSTALL_DIR}:\$PATH"

Then run:

  causet version
  causet-compiler about
EOF
}

main "$@"
