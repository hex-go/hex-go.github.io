#!/usr/bin/env bash
# Zed config sync helpers (WSL <-> GitHub dotfiles repo)
# zed-sync  : live Zed config + ~/ dotfiles  ->  repo  -> commit & push
# zed-setup : repo  ->  live Zed config + ~/ dotfiles
#
# This script lives INSIDE the repo (dotfiles/zed-config/zed-dotfiles.sh) so it
# is version-controlled and travels to every machine. Paths are auto-detected.
# Override with env vars ZED_LIVE / ZED_REPO if auto-detect fails.

# --- locate repo root: script is at <repo>/dotfiles/zed-config/zed-dotfiles.sh
_zed_self="${BASH_SOURCE[0]}"
_zed_self_dir="$(cd "$(dirname "$_zed_self")" && pwd)"
: "${ZED_REPO:=$(cd "$_zed_self_dir/../.." && pwd)}"

ZED_REPO_SUB="dotfiles/zed-config/zed"
ZED_FILES=(keymap.json settings.json tasks.json AGENTS.md)
ZED_DIRS=(themes)

# WSL home dotfiles (live in $HOME, backed by dotfiles/zed-config/wsl/).
# The cheat-sheet task (ctrl-shift-/) runs `bash ~/.zed-cheatsheet.sh`, so this
# file must land in $HOME on every machine or the shortcut breaks.
ZED_WSL_SUB="dotfiles/zed-config/wsl"
ZED_HOME_FILES=(.zed-cheatsheet.sh)

# Resolve the live Zed config dir lazily (only when a command runs, so we never
# slow down shell startup). Strategy, in order:
#   1) honour a user-provided $ZED_LIVE
#   2) glob /mnt/c/Users/*/AppData/Roaming/Zed  (no interop needed, fast)
#   3) fall back to cmd.exe %APPDATA% (needs WSL interop enabled)
_zed_resolve_live() {
  [ -n "$ZED_LIVE" ] && return 0

  local hits=(/mnt/c/Users/*/AppData/Roaming/Zed)
  local found=()
  local p
  for p in "${hits[@]}"; do
    [ -d "$p" ] && found+=("$p")
  done
  if [ "${#found[@]}" -eq 1 ]; then
    ZED_LIVE="${found[0]}"
    return 0
  elif [ "${#found[@]}" -gt 1 ]; then
    echo "[zed] multiple Zed config dirs found, set ZED_LIVE to pick one:" >&2
    printf '  %s\n' "${found[@]}" >&2
    return 1
  fi

  # fallback: ask Windows for %APPDATA%
  local appdata
  appdata="$(cmd.exe /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r')"
  if [ -n "$appdata" ]; then
    local wp
    wp="$(wslpath "$appdata" 2>/dev/null)/Zed"
    [ -d "$wp" ] && ZED_LIVE="$wp" && return 0
  fi
  return 1
}

_zed_check() {
  _zed_resolve_live
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

  # WSL home dotfiles -> repo dotfiles/zed-config/wsl
  local wdst="$ZED_REPO/$ZED_WSL_SUB"
  mkdir -p "$wdst"
  local hf
  for hf in "${ZED_HOME_FILES[@]}"; do
    if [ -f "$HOME/$hf" ]; then
      cp -f "$HOME/$hf" "$wdst/$hf"
      echo "  + wsl/$hf"
    fi
  done

  git -C "$ZED_REPO" add "$ZED_REPO_SUB" "$ZED_WSL_SUB"
  if git -C "$ZED_REPO" diff --cached --quiet -- "$ZED_REPO_SUB" "$ZED_WSL_SUB"; then
    echo "[zed] nothing changed, skip commit"
    return 0
  fi
  git -C "$ZED_REPO" commit -m "chore(zed): sync config $(date +%Y-%m-%d\ %H:%M)" -- "$ZED_REPO_SUB" "$ZED_WSL_SUB"
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

  # repo dotfiles/zed-config/wsl -> WSL home dotfiles
  local wsrc="$ZED_REPO/$ZED_WSL_SUB"
  echo "[zed] restoring home dotfiles -> $HOME"
  local hf
  for hf in "${ZED_HOME_FILES[@]}"; do
    if [ -f "$wsrc/$hf" ]; then
      [ -f "$HOME/$hf" ] && cp -f "$HOME/$hf" "$backup/$hf"
      cp -f "$wsrc/$hf" "$HOME/$hf"
      chmod +x "$HOME/$hf" 2>/dev/null
      echo "  + ~/$hf"
    fi
  done

  # the cheat-sheet task depends on python3; warn early if it's missing
  if ! command -v python3 >/dev/null 2>&1; then
    echo "[zed] WARNING: python3 not found — the cheat sheet (ctrl-shift-/) needs it." >&2
    echo "[zed]          install it, e.g.: sudo apt-get install -y python3" >&2
  fi

  echo "[zed] setup done. Fully restart Zed to apply."
}

# commands are exposed as functions zed-sync / zed-setup (zed- prefix)
