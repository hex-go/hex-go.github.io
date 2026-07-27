#!/usr/bin/env bash
# Bootstrap on a NEW machine — run once after cloning the repo:
#   bash <repo>/dotfiles/zed-config/bootstrap.sh
# It wires the versioned zed-dotfiles.sh into ~/.bashrc so that
# `sync` / `setup` become available in every new shell.

set -e
_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_target="$_dir/zed-dotfiles.sh"

if [ ! -f "$_target" ]; then
  echo "[zed] cannot find $_target" >&2
  exit 1
fi

_line="[ -f \"$_target\" ] && source \"$_target\""
if grep -qF "$_target" ~/.bashrc 2>/dev/null; then
  echo "[zed] already wired in ~/.bashrc"
else
  printf '\n# Zed config sync helpers\n%s\n' "$_line" >> ~/.bashrc
  echo "[zed] added source line to ~/.bashrc"
fi

# shellcheck disable=SC1090
source "$_target"
echo "[zed] loaded. Commands available now: sync / setup"
echo "[zed] (new shells will auto-load too)"
