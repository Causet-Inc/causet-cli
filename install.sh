#!/usr/bin/env bash
# Install Causet CLI + compiler from public GitHub Releases (Causet-Inc/causet-cli).
#
# Usage:
#   curl -fsSL https://install.causet.io/install.sh | bash
#   curl -fsSL https://install.causet.io/install.sh | env CAUSET_VERSION=v10.0.12 bash
#   export CAUSET_VERSION=v10.0.12 && curl -fsSL https://install.causet.io/install.sh | bash
#
# Do not use:
#   CAUSET_VERSION=v10.0.12 curl ... | bash
# that only sets the variable for curl, not for bash.
#
# Also published at:
#   https://raw.githubusercontent.com/Causet-Inc/causet-cli/main/install.sh
#
set -euo pipefail

REPO="${CAUSET_REPO:-Causet-Inc/causet-cli}"
INSTALL_DIR="${CAUSET_INSTALL_DIR:-${HOME}/.causet/bin}"
VERSION="${CAUSET_VERSION:-}"
VERIFY_CHECKSUMS="${CAUSET_VERIFY_CHECKSUMS:-1}"
SKIP_SHELL_SETUP="${CAUSET_SKIP_SHELL_SETUP:-0}"
SKIP_COMPILER="${CAUSET_SKIP_COMPILER:-0}"

CONFIG_BEGIN="# >>> causet shell setup >>>"
CONFIG_END="# <<< causet shell setup <<<"

INSTALLED_PATHS=()

cleanup_on_failure() {
  local code=$?
  if [[ "$code" -ne 0 && "${#INSTALLED_PATHS[@]}" -gt 0 ]]; then
    echo "error: install failed; removing partial files" >&2
    for path in "${INSTALLED_PATHS[@]}"; do
      rm -f "$path"
    done
  fi
  exit "$code"
}
trap cleanup_on_failure EXIT

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
    *) die "unsupported OS: ${raw_os} (macOS and Linux only; use WSL2 on Windows)" ;;
  esac

  case "$raw_arch" in
    x86_64|amd64)   ARCH=amd64 ;;
    arm64|aarch64)  ARCH=arm64 ;;
    *) die "unsupported CPU architecture: ${raw_arch}" ;;
  esac
}

resolve_cli_asset() {
  echo "causet-${OS}-${ARCH}"
}

resolve_compiler_candidates() {
  local primary="causet-compiler-${OS}-${ARCH}"
  echo "$primary"
  if [[ "$OS" == linux && "$ARCH" == arm64 ]]; then
    echo "causet-compiler-linux-amd64"
  fi
}

has_amd64_emulation() {
  if [[ "$OS" != linux || "$ARCH" != arm64 ]]; then
    return 0
  fi
  if [[ -r /proc/sys/fs/binfmt_misc/qemu-x86_64 || -r /proc/sys/fs/binfmt_misc/X86_64 ]]; then
    return 0
  fi
  if command -v qemu-x86_64 >/dev/null 2>&1; then
    return 0
  fi
  return 1
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
    if ! curl -fsSL "$url" -o "$dest"; then
      rm -f "$dest"
      return 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! wget -qO "$dest" "$url"; then
      rm -f "$dest"
      return 1
    fi
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
  if ! try_fetch "$(download_url checksums.txt)" "$checksums"; then
    rm -f "$checksums"
    die "could not download checksums.txt (release ${VERSION:-latest} may not exist)"
  fi
  expected="$(awk -v f="$asset" '$2 == f { print $1; exit }' "$checksums")"
  rm -f "$checksums"

  [[ -n "$expected" ]] || die "checksums.txt has no entry for ${asset}"

  if command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  elif command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  else
    die "Checksum verification cannot run. Install shasum or sha256sum, or explicitly set CAUSET_VERIFY_CHECKSUMS=0 to continue without verification."
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
  if ! try_fetch "$url" "$tmp"; then
    rm -f "$tmp"
    if [[ -n "$VERSION" ]]; then
      die "could not download ${asset} for release ${VERSION} (404 or network error)"
    fi
    die "could not download ${asset} from latest release (404 or network error)"
  fi
  verify_checksum "$asset" "$tmp"
  mkdir -p "$INSTALL_DIR"
  mv "$tmp" "$dest"
  chmod +x "$dest" 2>/dev/null || true
  INSTALLED_PATHS+=("$dest")
  echo "Installed ${dest}"
}

install_compiler() {
  if [[ "$SKIP_COMPILER" == "1" ]]; then
    echo "Skipping compiler install (CAUSET_SKIP_COMPILER=1)"
    echo "note: build, compile, and deploy commands that require causet-compiler will not work until a compiler is installed." >&2
    return 0
  fi

  local asset url tmp dest
  while IFS= read -r asset; do
    [[ -n "$asset" ]] || continue
    if [[ "$asset" == "causet-compiler-linux-amd64" && "$OS" == linux && "$ARCH" == arm64 ]]; then
      if ! has_amd64_emulation; then
        die "Linux ARM64 has no native compiler artifact and amd64 emulation was not detected. Install qemu-user/binfmt, use macOS ARM64 or Linux AMD64, or re-run with CAUSET_SKIP_COMPILER=1."
      fi
    fi
    url="$(download_url "$asset")"
    tmp="$(mktemp)"
    if try_fetch "$url" "$tmp" 2>/dev/null; then
      verify_checksum "$asset" "$tmp"
      dest="${INSTALL_DIR}/causet-compiler"
      mkdir -p "$INSTALL_DIR"
      mv "$tmp" "$dest"
      chmod +x "$dest" 2>/dev/null || true
      INSTALLED_PATHS+=("$dest")
      echo "Installed ${dest} (from ${asset})"
      if [[ "$asset" != "causet-compiler-${OS}-${ARCH}" ]]; then
        echo "note: causet-compiler-${OS}-${ARCH} is not published; using ${asset}" >&2
        if [[ "$OS" == linux && "$ARCH" == arm64 ]]; then
          echo "note: running the amd64 compiler on Linux ARM64 requires amd64 emulation (qemu-user / binfmt)" >&2
        fi
      fi
      return 0
    fi
    rm -f "$tmp"
  done < <(resolve_compiler_candidates)

  if [[ "$OS" == linux && "$ARCH" == arm64 ]]; then
    die "Linux ARM64 compiler is not published. Install with CAUSET_SKIP_COMPILER=1 (CLI only), use macOS ARM64 or Linux AMD64, or ensure amd64 emulation is available for the linux-amd64 compiler fallback."
  fi
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

  local cli_asset
  cli_asset="$(resolve_cli_asset)"
  install_asset "$cli_asset" "causet"
  install_compiler
  setup_shell

  trap - EXIT

  cat <<EOF

Causet CLI installed to ${INSTALL_DIR}

Shell PATH and tab completion were added to your shell config when supported
(zsh, bash, fish). Open a new terminal or run:

  source ~/.zshrc    # zsh
  source ~/.bashrc   # bash

Then run:

  causet version
  causet doctor

Wallet demo:

  causet new wallets my-wallets
  cd my-wallets
  causet local up
  npm run dev --prefix app

Set CAUSET_SKIP_SHELL_SETUP=1 to skip profile updates.
Set CAUSET_SKIP_COMPILER=1 to install only the CLI.
EOF
}

main "$@"
