#!/usr/bin/env bash
# Zed config sync helpers (WSL <-> GitHub dotfiles repo)
# sync  : live Zed config  ->  repo dotfiles/zed-config/zed  -> commit & push
# setup : repo dotfiles/zed-config/zed  ->  live Zed config
#
# This script lives INSIDE the repo (dotfiles/zed-config/zed-dotfiles.sh) so it
# is version-controlled and travels to every machine. Paths are auto-detected.
# Override with env vars ZED_LIVE / ZED_REPO if auto-detect fails.

# --- locate repo root: script is at <repo>/dotfiles/zed-config/zed-dotfiles.sh
_zed_self="${BASH_SOURCE[0]}"
_zed_self_dir="$(cd "$(dirname "$_zed_self")" && pwd)"
: "${ZED_REPO:=$(cd "$_zed_self_dir/../.." && pwd)}"

# --- locate live Zed config dir (%APPDATA%\Zed on the Windows host)
if [ -z "$ZED_LIVE" ]; then
  _appdata="$(cmd.exe /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r')"
  if [ -n "$_appdata" ]; then
    ZED_LIVE="$(wslpath "$_appdata" 2>/dev/null)/Zed"
  fi
fi

ZED_REPO_SUB="dotfiles/zed-config/zed"
ZED_FILES=(keymap.json settings.json tasks.json AGENTS.md)
ZED_DIRS=(themes)

_zed_check() {
  if [ -z "$ZED_LIVE" ] || [ ! -d "$ZED_LIVE" ]; then
    echo "[zed] live config dir not found: ${ZED_LIVE:-<empty>}" >&2
    echo "[zed] set it manually: export ZED_LIVE=/mnt/c/Users/<you>/AppData/Roaming/Zed" >&2
    return 1
  fi
  if [ ! -d "$ZED_REPO/.git" ]; then
    echo "[zed] repo not found: $ZED_REPO" >&2
    return 1
  fi
}

zed-sync() {
  _zed_check || return 1
  local dst="$ZED_REPO/$ZED_REPO_SUB"
  mkdir -p "$dst"
  echo "[zed] archiving live config -> $dst"
  local f
  for f in "${ZED_FILES[@]}"; do
    if [ -f "$ZED_LIVE/$f" ]; then
      cp -f "$ZED_LIVE/$f" "$dst/$f"
      echo "  + $f"
    fi
  done
  local d
  for d in "${ZED_DIRS[@]}"; do
    if [ -d "$ZED_LIVE/$d" ]; then
      rm -rf "$dst/$d"
      cp -rf "$ZED_LIVE/$d" "$dst/$d"
      echo "  + $d/"
    fi
  done
  git -C "$ZED_REPO" add "$ZED_REPO_SUB"
  if git -C "$ZED_REPO" diff --cached --quiet -- "$ZED_REPO_SUB"; then
    echo "[zed] nothing changed, skip commit"
    return 0
  fi
  git -C "$ZED_REPO" commit -m "chore(zed): sync config $(date +%Y-%m-%d\ %H:%M)" -- "$ZED_REPO_SUB"
  echo "[zed] pushing..."
  git -C "$ZED_REPO" push origin "$(git -C "$ZED_REPO" branch --show-current)"
  echo "[zed] sync done"
}

zed-setup() {
  _zed_check || return 1
  echo "[zed] pulling latest from origin..."
  git -C "$ZED_REPO" pull --ff-only origin "$(git -C "$ZED_REPO" branch --show-current)"
  local src="$ZED_REPO/$ZED_REPO_SUB"
  if [ ! -d "$src" ]; then
    echo "[zed] repo config dir not found: $src" >&2
    return 1
  fi
  local ts backup
  ts=$(date +%Y%m%d-%H%M%S)
  backup="$ZED_LIVE/.backup-$ts"
  mkdir -p "$backup"
  echo "[zed] restoring config -> $ZED_LIVE (backup: $backup)"
  local f
  for f in "${ZED_FILES[@]}"; do
    if [ -f "$src/$f" ]; then
      [ -f "$ZED_LIVE/$f" ] && cp -f "$ZED_LIVE/$f" "$backup/$f"
      cp -f "$src/$f" "$ZED_LIVE/$f"
      echo "  + $f"
    fi
  done
  local d
  for d in "${ZED_DIRS[@]}"; do
    if [ -d "$src/$d" ]; then
      [ -d "$ZED_LIVE/$d" ] && cp -rf "$ZED_LIVE/$d" "$backup/$d"
      rm -rf "$ZED_LIVE/$d"
      cp -rf "$src/$d" "$ZED_LIVE/$d"
      echo "  + $d/"
    fi
  done
  echo "[zed] setup done. Fully restart Zed to apply."
}

alias sync='zed-sync'
alias setup='zed-setup'
