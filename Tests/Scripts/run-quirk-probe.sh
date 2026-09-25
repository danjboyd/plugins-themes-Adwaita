#!/usr/bin/env bash
# Copyright (C) 2025-2026 Daniel Boyd
#
# This file is part of the GNUstep Adwaita theme.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; see the file COPYING.LIB.
# If not, see <http://www.gnu.org/licenses/>.

# Runs Examples/QuirkProbe against the theme bundle built in this checkout, on
# a private Xvfb display. Prints PASS/FAIL/KNOWN/SKIP per check and exits with
# the number of failures (1 for a setup error).
#
#   bash Tests/Scripts/run-quirk-probe.sh [--theme PATH] [--output DIR]
#                                         [--display :N] [--no-build]
#
# --output DIR  also writes a PNG of each probe window to DIR.
# --display :N  uses an existing X display instead of starting Xvfb.

set -eu

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
THEME="${ADWAITA_THEME:-$REPO_DIR/Adwaita.theme}"
OUTPUT=""
USE_DISPLAY=""
BUILD=1
XVFB_PID=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --theme)
      THEME="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --display)
      USE_DISPLAY="$2"
      shift 2
      ;;
    --no-build)
      BUILD=0
      shift
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

set +u
. /usr/GNUstep/System/Library/Makefiles/GNUstep.sh
set -u

LOG="$(mktemp --suffix=.quirk-probe.log)"
SETTINGS_DIR="$(mktemp -d --suffix=.quirk-probe)"

cleanup() {
  if [ -n "$XVFB_PID" ]; then
    kill "$XVFB_PID" >/dev/null 2>&1 || true
    wait "$XVFB_PID" 2>/dev/null || true
  fi
  rm -rf "$SETTINGS_DIR"
}
trap cleanup EXIT

if [ "$BUILD" -eq 1 ]; then
  if ! make -C "$REPO_DIR" >>"$LOG" 2>&1 \
    || ! make -C "$REPO_DIR/Examples/QuirkProbe" >>"$LOG" 2>&1; then
    echo "build failed; see $LOG" >&2
    exit 1
  fi
fi

if [ ! -d "$THEME" ]; then
  echo "theme bundle not found: $THEME (run make first)" >&2
  exit 1
fi
THEME="$(cd "$THEME" && pwd)"

PROBE="$REPO_DIR/Examples/QuirkProbe/QuirkProbe.app/QuirkProbe"
if [ ! -x "$PROBE" ]; then
  echo "probe not built: $PROBE" >&2
  exit 1
fi

if [ -n "$USE_DISPLAY" ]; then
  export DISPLAY="$USE_DISPLAY"
else
  for n in $(seq 90 120); do
    if [ ! -e "/tmp/.X11-unix/X$n" ] && [ ! -e "/tmp/.X$n-lock" ]; then
      break
    fi
  done
  Xvfb ":$n" -screen 0 1280x800x24 -nolisten tcp >>"$LOG" 2>&1 &
  XVFB_PID=$!
  for _ in $(seq 1 50); do
    [ -e "/tmp/.X11-unix/X$n" ] && break
    sleep 0.1
  done
  export DISPLAY=":$n"
fi

# The checks assume GNOME's default look (light, Cantarell 11), whatever this
# desktop uses: give the probe its own GSettings with those values.
mkdir -p "$SETTINGS_DIR/glib-2.0/settings"
cat >"$SETTINGS_DIR/glib-2.0/settings/keyfile" <<'KEYFILE'
[org/gnome/desktop/interface]
color-scheme='default'
gtk-theme='Adwaita'
font-name='Cantarell 11'
monospace-font-name='Noto Sans Mono 11'
KEYFILE

PROBE_ARGS=(-GSTheme "$THEME" -NSMenuInterfaceStyle NSWindows95InterfaceStyle)
if [ -n "$OUTPUT" ]; then
  mkdir -p "$OUTPUT"
  PROBE_ARGS+=(-ProbeOutput "$(cd "$OUTPUT" && pwd)")
fi

RESULTS="$(mktemp --suffix=.quirk-probe.out)"
set +e
GSETTINGS_BACKEND=keyfile XDG_CONFIG_HOME="$SETTINGS_DIR" \
  timeout 60 "$PROBE" "${PROBE_ARGS[@]}" >"$RESULTS" 2>>"$LOG"
STATUS=$?
set -e
cat "$RESULTS"

# GNUstep falls back to another theme (or the default) without failing, and
# a bundle it can't load still reports its path, so check both the path and
# the theme class.
LOADED="$(sed -n 's/^THEME //p' "$RESULTS")"
LOADED_CLASS="$(sed -n 's/^THEMECLASS //p' "$RESULTS")"
if [ "$LOADED" != "$THEME" ] || [ "$LOADED_CLASS" != "GnomeTheme" ]; then
  echo "probe loaded theme '$LOADED' ($LOADED_CLASS), expected '$THEME' (GnomeTheme)" >&2
  exit 1
fi
if [ "$STATUS" -eq 124 ]; then
  echo "probe timed out; see $LOG" >&2
  exit 1
fi
if ! grep -q '^SUMMARY ' "$RESULTS"; then
  echo "probe exited early (status $STATUS); see $LOG" >&2
  exit 1
fi
exit "$STATUS"
