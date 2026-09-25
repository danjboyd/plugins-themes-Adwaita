#!/usr/bin/env bash
# Copyright (C) 2026 Daniel Boyd
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

# Checks the header bar with Mutter as the window manager: GNOME Shell runs
# as the X11 window manager of a private Xvfb display, with its own D-Bus
# session, settings in memory and scratch XDG directories, so the desktop
# session isn't touched. ThemeDemo runs with the header bar; xdotool clicks
# on that display only.
#
# The session runs without gvfs (GIO_USE_VFS=local, no FUSE mount, no
# volume monitors). With gvfs it mounts whatever devices are plugged in
# (a phone, a camera) under its runtime directory, and a recursive delete
# of the scratch directory would reach into them. Cleanup also stops every
# process of the session, unmounts anything left, and deletes without
# crossing into another file system.
#
# Checked: Mutter may move, maximise, minimise and close the window
# (_MOTIF_WM_HINTS, _NET_WM_ALLOWED_ACTIONS); a double-click on the bar has
# Mutter maximise it and a second one restore it to the same frame; a drag
# on the bar, handed to Mutter, takes the window past the screen's left
# edge (GNUstep's own move loop can't); a drag on the right edge, handed
# to Mutter, widens it.
#
#   bash Tests/Scripts/run-mutter-check.sh [--no-build]

set -u

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
THEME="$REPO_DIR/Adwaita.theme"
DEMO="$REPO_DIR/Examples/ThemeDemo/ThemeDemo.app/ThemeDemo"
WORK="$(mktemp -d --suffix=.mutter-check)"
FAILED=0
PIDS=()

# The session's processes, found by its runtime directory: dbus-run-session
# leaves the daemons it started running after GNOME Shell exits.
session_pids() {
  local pid
  for pid in $(pgrep -u "$(id -u)"); do
    if { tr '\0' '\n' <"/proc/$pid/environ"; } 2>/dev/null | grep -qxF "XDG_RUNTIME_DIR=$WORK/run"; then
      echo "$pid"
    fi
  done
}

cleanup() {
  local mount
  for pid in "${PIDS[@]}" $(session_pids); do
    kill "$pid" >/dev/null 2>&1 || true
  done
  sleep 1
  for mount in $(awk -v w="$WORK" 'index($2, w) == 1 {print $2}' /proc/mounts); do
    fusermount -u "$mount" >/dev/null 2>&1 || umount "$mount" >/dev/null 2>&1 || true
  done
  if awk -v w="$WORK" 'index($2, w) == 1 {found = 1} END {exit !found}' /proc/mounts; then
    echo "not deleting $WORK: something is still mounted in it" >&2
    return
  fi
  rm -rf --one-file-system "$WORK"
}
trap cleanup EXIT

for tool in Xvfb gnome-shell dbus-run-session xdotool xprop; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "SKIP  mutter: $tool not installed"
    exit 0
  fi
done

set +u
. /usr/GNUstep/System/Library/Makefiles/GNUstep.sh
set -u

if [ "${1:-}" != "--no-build" ]; then
  make -C "$REPO_DIR" >/dev/null 2>&1 && make -C "$REPO_DIR/Examples/ThemeDemo" >/dev/null 2>&1 \
    || { echo "build failed" >&2; exit 1; }
fi

for n in $(seq 120 150); do
  [ ! -e "/tmp/.X11-unix/X$n" ] && [ ! -e "/tmp/.X$n-lock" ] && break
done
export DISPLAY=":$n"
Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp +extension GLX +extension RANDR >/dev/null 2>&1 &
PIDS+=($!)
sleep 1

mkdir -p "$WORK"/{config,data,cache,state,run,gs/glib-2.0/settings}
chmod 700 "$WORK/run"
env -i HOME="$HOME" PATH="$PATH" DISPLAY="$DISPLAY" XDG_CONFIG_HOME="$WORK/config" \
  XDG_DATA_HOME="$WORK/data" XDG_CACHE_HOME="$WORK/cache" XDG_STATE_HOME="$WORK/state" \
  XDG_RUNTIME_DIR="$WORK/run" GSETTINGS_BACKEND=memory LIBGL_ALWAYS_SOFTWARE=1 \
  GIO_USE_VFS=local GVFS_DISABLE_FUSE=1 GIO_USE_VOLUME_MONITOR=unix \
  dbus-run-session -- gnome-shell --x11 >"$WORK/shell.log" 2>&1 &
PIDS+=($!)
for _ in $(seq 1 60); do
  xprop -root _NET_SUPPORTING_WM_CHECK 2>/dev/null | grep -q "window id" && break
  sleep 0.5
done
sleep 4
# GNOME Shell starts in the overview, and a first run shows a welcome
# dialog: close both.
xdotool key Escape; sleep 1; xdotool key Escape; sleep 1

cat >"$WORK/gs/glib-2.0/settings/keyfile" <<'KEYFILE'
[org/gnome/desktop/interface]
color-scheme='default'
font-name='Cantarell 11'

[org/gnome/desktop/wm/preferences]
button-layout='appmenu:minimize,maximize,close'
action-double-click-titlebar='toggle-maximize'
KEYFILE
GSETTINGS_BACKEND=keyfile XDG_CONFIG_HOME="$WORK/gs" \
  "$DEMO" -GSTheme "$THEME" -GSX11HandlesWindowDecorations NO >"$WORK/demo.log" 2>&1 &
PIDS+=($!)

WINDOW=""
for _ in $(seq 1 40); do
  WINDOW="$(xdotool search --name "Adwaita Theme Demo" 2>/dev/null | head -1)"
  [ -n "$WINDOW" ] && break
  sleep 0.5
done
if [ -z "$WINDOW" ]; then
  echo "FAIL  mutter-setup: ThemeDemo's window didn't appear"
  exit 1
fi
sleep 2

report() { # status ident detail
  printf '%-5s %s: %s\n' "$1" "$2" "$3"
  [ "$1" = FAIL ] && FAILED=$((FAILED + 1))
  return 0
}

geometry() {
  xdotool getwindowgeometry "$WINDOW" | awk '/Position/ {p=$2} /Geometry/ {g=$2} END {print p, g}'
}

# A point on the header bar, clear of the title and buttons.
bar_point() {
  eval "$(xdotool getwindowgeometry --shell "$WINDOW")"
  echo "$((X + 60)) $((Y + 20))"
}

ACTIONS="$(xprop -id "$WINDOW" _NET_WM_ALLOWED_ACTIONS)"
if echo "$ACTIONS" | grep -q _NET_WM_ACTION_MOVE && echo "$ACTIONS" | grep -q _NET_WM_ACTION_MAXIMIZE_VERT \
  && echo "$ACTIONS" | grep -q _NET_WM_ACTION_CLOSE; then
  report PASS mutter-allowed-actions "move, maximise and close allowed"
else
  report FAIL mutter-allowed-actions "$ACTIONS"
fi

BEFORE="$(geometry)"
read -r PX PY <<<"$(bar_point)"
xdotool mousemove "$PX" "$PY" click --repeat 2 --delay 120 1
sleep 1.5
STATE="$(xprop -id "$WINDOW" _NET_WM_STATE)"
MAXIMISED="$(geometry)"
if echo "$STATE" | grep -q MAXIMIZED_VERT && echo "$STATE" | grep -q MAXIMIZED_HORZ; then
  report PASS mutter-maximise "$BEFORE -> $MAXIMISED, maximised by Mutter"
else
  report FAIL mutter-maximise "$BEFORE -> $MAXIMISED; $STATE"
fi

read -r PX PY <<<"$(bar_point)"
xdotool mousemove "$PX" "$PY" click --repeat 2 --delay 120 1
sleep 1.5
STATE="$(xprop -id "$WINDOW" _NET_WM_STATE)"
AFTER="$(geometry)"
if ! echo "$STATE" | grep -q MAXIMIZED && [ "$AFTER" = "$BEFORE" ]; then
  report PASS mutter-restore "back to $AFTER"
else
  report FAIL mutter-restore "$AFTER (was $BEFORE); $STATE"
fi

# A drag on the bar, 350px to the left: Mutter moves the window, past the
# screen's edge.
eval "$(xdotool getwindowgeometry --shell "$WINDOW")"
xdotool mousemove "$((X + 160))" "$((Y + 20))"; sleep 0.3; xdotool mousedown 1; sleep 0.2
for _ in $(seq 1 35); do xdotool mousemove_relative -- -10 0; sleep 0.02; done
sleep 0.3; xdotool mouseup 1; sleep 1
MOVED="$(geometry)"
eval "$(xdotool getwindowgeometry --shell "$WINDOW")"
if [ "$X" -lt 0 ]; then
  report PASS mutter-move "$AFTER -> $MOVED, past the left edge"
else
  report FAIL mutter-move "$AFTER -> $MOVED (not moved past the left edge: the move wasn't handed to Mutter)"
fi

# A drag on the right edge, 100px: Mutter widens the window.
eval "$(xdotool getwindowgeometry --shell "$WINDOW")"
OLD_WIDTH=$WIDTH
xdotool mousemove "$((X + WIDTH - 2))" "$((Y + HEIGHT / 2))"; sleep 0.3; xdotool mousedown 1; sleep 0.2
for _ in $(seq 1 20); do xdotool mousemove_relative -- 5 0; sleep 0.02; done
sleep 0.3; xdotool mouseup 1; sleep 1
eval "$(xdotool getwindowgeometry --shell "$WINDOW")"
if [ "$WIDTH" -ge $((OLD_WIDTH + 80)) ]; then
  report PASS mutter-resize "width $OLD_WIDTH -> $WIDTH"
else
  report FAIL mutter-resize "width $OLD_WIDTH -> $WIDTH"
fi

echo "SUMMARY mutter failed=$FAILED"
exit "$FAILED"
