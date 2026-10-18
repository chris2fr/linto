#!/usr/bin/env bash
# linto-complete: none
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: mdsetup.sh [-h|--help]

Install available Markdown viewers and mandown for Linto guide pages. Linto
selects the first installed viewer in this order: md-tui, mdcat, mandown,
glow, bat, mdfried, mdless. It falls back to plain cat when none is installed.
NOTE TO SELF ; md2roff, groff-dejavu, groff-utf8, md-tui, mdcat
EOF
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  '') ;;
  *) usage >&2; exit 2 ;;
esac

fail() {
  printf 'mdsetup: %s\n' "$*" >&2
  exit 1
}

# All of these are optional viewers; do not install every one just to render
# guide pages. Pick the best currently installed one and report that choice.
viewers=(md-tui mdcat mandown glow bat mdfried mdless)
selected=
for viewer in "${viewers[@]}"; do
  if command -v "$viewer" >/dev/null 2>&1; then
    selected=$viewer
    break
  fi
done

if [[ -n "$selected" ]]; then
  printf 'Markdown viewer: %s\n' "$selected"
else
  printf 'No supported Markdown viewer is installed; Linto will use cat.\n'
fi

missing=()
command -v mandown >/dev/null 2>&1 || missing+=(mandown)
if [[ -z "$selected" ]]; then
  missing+=(mdcat)
fi

if ((${#missing[@]} == 0)); then
  printf 'Markdown prerequisites are already installed.\n'
  exit 0
fi

# Prefer distro packages for a system-managed installation.
if command -v pacman >/dev/null 2>&1; then
  packages=()
  for tool in "${missing[@]}"; do
    case "$tool" in
      mdcat) packages+=(mdcat) ;;
      mandown) packages+=(mandown) ;;
    esac
  done
  if ((EUID == 0)); then
    pacman -S --needed "${packages[@]}"
  elif command -v sudo >/dev/null 2>&1; then
    sudo pacman -S --needed "${packages[@]}"
  else
    fail "missing ${missing[*]}; install packages ${packages[*]} with pacman as root (sudo is unavailable)"
  fi
elif command -v apt-get >/dev/null 2>&1; then
  packages=()
  for tool in "${missing[@]}"; do
    case "$tool" in
      mdcat) packages+=(mdcat) ;;
      mandown) packages+=(mandown) ;;
    esac
  done
  if ((EUID == 0)); then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
  elif command -v sudo >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y "${packages[@]}"
  else
    fail "missing ${missing[*]}; install packages ${packages[*]} with apt-get as root (sudo is unavailable)"
  fi
elif command -v dnf >/dev/null 2>&1; then
  packages=()
  for tool in "${missing[@]}"; do
    case "$tool" in
      mdcat) packages+=(mdcat) ;;
      mandown) packages+=(mandown) ;;
    esac
  done
  if ((EUID == 0)); then
    dnf install -y "${packages[@]}"
  elif command -v sudo >/dev/null 2>&1; then
    sudo dnf install -y "${packages[@]}"
  else
    fail "missing ${missing[*]}; install packages ${packages[*]} with dnf as root (sudo is unavailable)"
  fi
elif command -v brew >/dev/null 2>&1; then
  for tool in "${missing[@]}"; do
    case "$tool" in
      mdcat) brew install mdcat ;;
      mandown)
        if command -v cargo >/dev/null 2>&1; then
          cargo install mandown
        else
          printf 'mdsetup: no Homebrew formula or Cargo available for mandown; install it separately.\n' >&2
        fi
        ;;
    esac
  done
elif command -v cargo >/dev/null 2>&1; then
  for tool in "${missing[@]}"; do
    case "$tool" in
      mdcat) cargo install mdcat ;;
      mandown) printf 'mdsetup: install mandown with your system package manager.\n' >&2 ;;
    esac
  done
else
  fail "missing ${missing[*]}; install mdcat and mandown with your system package manager (or install mdcat with cargo)"
fi

missing_after=()
command -v mdcat >/dev/null 2>&1 || missing_after+=(mdcat)
command -v mandown >/dev/null 2>&1 || missing_after+=(mandown)
if ((${#missing_after[@]} > 0)); then
  fail "installation did not provide: ${missing_after[*]}"
fi
printf 'Markdown prerequisites are ready (mdcat, mandown).\n'
