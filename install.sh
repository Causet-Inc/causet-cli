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
SKIP_SHELL_SETUP="${CAUSET_SKIP_SHELL_SETUP:-0}"

CONFIG_BEGIN="# >>> causet shell setup >>>"
CONFIG_END="# <<< causet shell setup <<<"

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

upsert_shell_block() {
  local rc_file=$1
  local block=$2

  mkdir -p "$(dirname "$rc_file")"
  touch "$rc_file"

  if grep -qF "$CONFIG_BEGIN" "$rc_file" 2>/dev/null; then
    echo "Shell setup already present in ${rc_file}"
    return 0
  fi

  {
    echo ""
    echo "$CONFIG_BEGIN"
    printf '%s\n' "$block"
    echo "$CONFIG_END"
  } >>"$rc_file"
  echo "Updated ${rc_file}"
}

setup_shell() {
  [[ "$SKIP_SHELL_SETUP" == "1" ]] && return 0

  local causet_bin="${INSTALL_DIR}/causet"
  local shell_name path_line completion_line block

  shell_name="$(basename "${SHELL:-}")"
  path_line="export PATH=\"${INSTALL_DIR}:\$PATH\""

  case "$shell_name" in
    zsh)
      completion_line="eval \"\$(${causet_bin} completion zsh)\""
      block="${path_line}
${completion_line}"
      upsert_shell_block "${ZDOTDIR:-$HOME}/.zshrc" "$block"
      ;;
    bash)
      completion_line="eval \"\$(${causet_bin} completion bash)\""
      block="${path_line}
${completion_line}"
      upsert_shell_block "$HOME/.bashrc" "$block"
      ;;
    fish)
      mkdir -p "$HOME/.config/fish/completions"
      "$causet_bin" completion fish >"$HOME/.config/fish/completions/causet.fish"
      echo "Wrote fish completion to ${HOME}/.config/fish/completions/causet.fish"
      upsert_shell_block "$HOME/.config/fish/config.fish" "fish_add_path ${INSTALL_DIR}"
      ;;
    *)
      echo "note: add PATH and completion manually for ${shell_name}:"
      echo "  ${path_line}"
      echo "  eval \"\$(${causet_bin} completion ${shell_name})\""
      ;;
  esac
}

main() {
  require_cmd uname
  detect_platform

  local cli_asset="causet-${OS}-${ARCH}"
  install_asset "$cli_asset" "causet"
  install_compiler_with_fallback
  setup_shell

  cat <<EOF

Causet CLI installed to ${INSTALL_DIR}

Shell PATH and tab completion were added to your shell config when supported
(zsh, bash, fish). Open a new terminal or run:

  source ~/.zshrc    # zsh
  source ~/.bashrc   # bash

Then run:

  causet version
  causet-compiler about
  causet <TAB>       # tab completion for subcommands and flags

Set CAUSET_SKIP_SHELL_SETUP=1 to skip profile updates.
EOF
}

main "$@"
