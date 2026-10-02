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
# session, settings in a scratch keyfile (a solid grey background, so
# shadows can be measured) and scratch XDG directories, so the desktop
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
# --shadow runs against a libs-gui and libs-back that draw GNOME's window
# shadow (phase 2b in Docs/HANDOFF_HEADER_BAR.md): MUTTER_CHECK_GUI is the
# directory holding that libgnustep-gui.so, MUTTER_CHECK_BACK that
# libgnustep-back bundle. GNUstep's user defaults are an empty scratch
# directory, so the theme alone asks for the decorations and the shadow,
# and the backend is linked into a scratch user Library. Also checked: a
# 32-bit window with GNOME's frame extents, a shadow outside the edge and
# rounded corners; a menu with rounded corners (a borderless window with an
# alpha channel); maximised, no margin and square corners; restored, the
# margin back and the same frame; the edges resize from the band outside
# the window (not from inside), and a press further out in the shadow
# goes to what is behind.
#
#   bash Tests/Scripts/run-mutter-check.sh [--no-build] [--shadow]

set -u

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
THEME="$REPO_DIR/Adwaita.theme"
DEMO="$REPO_DIR/Examples/ThemeDemo/ThemeDemo.app/ThemeDemo"
WORK="$(mktemp -d --suffix=.mutter-check)"
FAILED=0
PIDS=()
BUILD=YES
SHADOW=NO
NAME=mutter

for arg in "$@"; do
  case "$arg" in
    --no-build) BUILD=NO ;;
    --shadow) SHADOW=YES; NAME=mutter-shadow ;;
  esac
done

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

for tool in Xvfb gnome-shell dbus-run-session xdotool xprop xwininfo import convert; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "SKIP  $NAME: $tool not installed"
    exit 0
  fi
done
if [ "$SHADOW" = YES ]; then
  if [ ! -e "${MUTTER_CHECK_GUI:-}/libgnustep-gui.so" ] || [ ! -d "${MUTTER_CHECK_BACK:-}" ]; then
    echo "SKIP  $NAME: set MUTTER_CHECK_GUI and MUTTER_CHECK_BACK to a shadow-drawing libs-gui and libs-back"
    exit 0
  fi
fi

set +u
. /usr/GNUstep/System/Library/Makefiles/GNUstep.sh
set -u

if [ "$BUILD" = YES ]; then
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

# A solid background: shadows are measured against it.
BACKGROUND=119
mkdir -p "$WORK"/{config/glib-2.0/settings,data,cache,state,run,gs/glib-2.0/settings}
chmod 700 "$WORK/run"
cat >"$WORK/config/glib-2.0/settings/keyfile" <<'KEYFILE'
[org/gnome/desktop/background]
picture-uri=''
picture-uri-dark=''
picture-options='none'
color-shading-type='solid'
primary-color='#777777'
KEYFILE
env -i HOME="$HOME" PATH="$PATH" DISPLAY="$DISPLAY" XDG_CONFIG_HOME="$WORK/config" \
  XDG_DATA_HOME="$WORK/data" XDG_CACHE_HOME="$WORK/cache" XDG_STATE_HOME="$WORK/state" \
  XDG_RUNTIME_DIR="$WORK/run" GSETTINGS_BACKEND=keyfile LIBGL_ALWAYS_SOFTWARE=1 \
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
if [ "$SHADOW" = YES ]; then
  # Empty user defaults (the theme alone asks for the decorations), and a
  # user Library holding the backend, all in the scratch directory.
  mkdir -p "$WORK/gsdefaults" "$WORK/gslibrary/Bundles"
  ln -s "$MUTTER_CHECK_BACK" "$WORK/gslibrary/Bundles/libgnustep-backshadow-032.bundle"
  sed -e "s|^GNUSTEP_USER_DEFAULTS_DIR=.*|GNUSTEP_USER_DEFAULTS_DIR=$WORK/gsdefaults|" \
      -e "s|^GNUSTEP_USER_DIR_LIBRARY=.*|GNUSTEP_USER_DIR_LIBRARY=$WORK/gslibrary|" \
      "${GNUSTEP_CONFIG_FILE:-/etc/GNUstep/GNUstep.conf}" >"$WORK/GNUstep.conf"
  chmod 600 "$WORK/GNUstep.conf"
  GNUSTEP_CONFIG_FILE="$WORK/GNUstep.conf" LD_LIBRARY_PATH="$MUTTER_CHECK_GUI:${LD_LIBRARY_PATH:-}" \
  GSETTINGS_BACKEND=keyfile XDG_CONFIG_HOME="$WORK/gs" \
    "$DEMO" -GSTheme "$THEME" -GSBackend libgnustep-backshadow >"$WORK/demo.log" 2>&1 &
else
  GSETTINGS_BACKEND=keyfile XDG_CONFIG_HOME="$WORK/gs" \
    "$DEMO" -GSTheme "$THEME" -GSX11HandlesWindowDecorations NO >"$WORK/demo.log" 2>&1 &
fi
DEMO_PID=$!
PIDS+=($DEMO_PID)

WINDOW=""
for _ in $(seq 1 40); do
  WINDOW="$(xdotool search --name "Adwaita Theme Demo" 2>/dev/null | head -1)"
  [ -n "$WINDOW" ] && break
  sleep 0.5
done
if [ -z "$WINDOW" ]; then
  echo "FAIL  $NAME-setup: ThemeDemo's window didn't appear"
  exit 1
fi
sleep 2

report() { # status ident detail
  printf '%-5s %s: %s\n' "$1" "$2" "$3"
  [ "$1" = FAIL ] && FAILED=$((FAILED + 1))
  return 0
}

if [ "$SHADOW" = YES ]; then
  if ! grep -q "$MUTTER_CHECK_BACK" "/proc/$DEMO_PID/maps" 2>/dev/null \
    || ! grep -q "$MUTTER_CHECK_GUI/libgnustep-gui" "/proc/$DEMO_PID/maps" 2>/dev/null; then
    report FAIL "$NAME-setup" "ThemeDemo didn't load the libraries given"
    echo "SUMMARY $NAME failed=$FAILED"
    exit "$FAILED"
  fi
fi

geometry() {
  xdotool getwindowgeometry "$WINDOW" | awk '/Position/ {p=$2} /Geometry/ {g=$2} END {print p, g}'
}

# The shadow margin (left right top bottom), 0 0 0 0 without one.
extents() {
  local e
  e="$(xprop -id "$WINDOW" _GTK_FRAME_EXTENTS 2>/dev/null | sed -n 's/.*= //p' | tr -d ,)"
  echo "${e:-0 0 0 0}"
}

# The visible window: the X window less the shadow margin.
visible() {
  local l r t b
  read -r l r t b <<<"$(extents)"
  eval "$(xdotool getwindowgeometry --shell "$WINDOW")"
  echo "$((X + l)) $((Y + t)) $((WIDTH - l - r)) $((HEIGHT - t - b))"
}

# A point on the header bar, clear of the title and buttons.
bar_point() {
  local vx vy vw vh
  read -r vx vy vw vh <<<"$(visible)"
  echo "$((vx + 30)) $((vy + 20))"
}

# Red + green + blue of a screen pixel.
pixel() { # x y
  import -window root "$WORK/screen.png" 2>/dev/null
  convert "$WORK/screen.png" -format "%[fx:round(255*(p{$1,$2}.r+p{$1,$2}.g+p{$1,$2}.b))]" info:
}

# The window under a screen point.
window_at() { # x y
  xdotool mousemove "$1" "$2"; sleep 0.3
  xdotool getmouselocation --shell | sed -n 's/^WINDOW=//p'
}

# Drags from a point by (dx, dy) in eight steps.
drag() { # x y dx dy
  xdotool mousemove "$1" "$2"; sleep 0.3; xdotool mousedown 1; sleep 0.2
  for _ in $(seq 1 8); do xdotool mousemove_relative -- "$3" "$4"; sleep 0.03; done
  sleep 0.3; xdotool mouseup 1; sleep 1
}

ACTIONS="$(xprop -id "$WINDOW" _NET_WM_ALLOWED_ACTIONS)"
if echo "$ACTIONS" | grep -q _NET_WM_ACTION_MOVE && echo "$ACTIONS" | grep -q _NET_WM_ACTION_MAXIMIZE_VERT \
  && echo "$ACTIONS" | grep -q _NET_WM_ACTION_CLOSE; then
  report PASS "$NAME-allowed-actions" "move, maximise and close allowed"
else
  report FAIL "$NAME-allowed-actions" "$ACTIONS"
fi

if [ "$SHADOW" = YES ]; then
  DEPTH="$(xwininfo -id "$WINDOW" | awk '/Depth:/ {print $2}')"
  EXTENTS="$(extents)"
  if [ "$DEPTH" = 32 ] && [ "$EXTENTS" = "30 30 24 36" ]; then
    report PASS "$NAME-window" "depth $DEPTH, frame extents $EXTENTS"
  else
    report FAIL "$NAME-window" "depth $DEPTH, frame extents $EXTENTS (want 32, 30 30 24 36)"
  fi

  # Darker than the background just outside the right edge, the
  # background past the margin; the top left corner rounded off, the top
  # edge further along the window's.
  read -r VX VY VW VH <<<"$(visible)"
  NEAR="$(pixel $((VX + VW + 3)) $((VY + VH / 2)))"
  FAR="$(pixel $((VX + VW + 40)) $((VY + VH / 2)))"
  CORNER="$(pixel "$VX" "$VY")"
  EDGE="$(pixel $((VX + 40)) "$VY")"
  DETAIL="r+g+b 3px out $NEAR, 40px out $FAR (background $((3 * BACKGROUND))); top left corner $CORNER, top edge $EDGE"
  if [ "$NEAR" -le $((FAR - 20)) ] && [ "$FAR" -ge $((3 * BACKGROUND - 6)) ] && [ "$FAR" -le $((3 * BACKGROUND + 6)) ] \
    && [ "$CORNER" -le 600 ] && [ "$EDGE" -ge 700 ]; then
    report PASS "$NAME-shadow-corners" "$DETAIL"
  else
    report FAIL "$NAME-shadow-corners" "$DETAIL"
  fi
fi

if [ "$SHADOW" = YES ]; then
  # A menu: a borderless window with an alpha channel
  # (GSBackBorderlessWindowAlpha), its corners rounded off to show what's
  # behind it, as libadwaita's: its bottom left pixel is what's there once
  # the menu has closed (a square menu has its border there).
  read -r VX VY VW VH <<<"$(visible)"
  xdotool mousemove $((VX + 30)) $((VY + 64)) click 1
  sleep 1
  MENU=""
  for w in $(xwininfo -root -children | awk '/^ +0x/ {print $1}'); do
    if [ "$((w))" != "$WINDOW" ] && xwininfo -id "$w" | grep -q 'IsViewable' \
      && xwininfo -id "$w" | grep -q 'Depth: 32' && xprop -id "$w" WM_CLASS 2>/dev/null | grep -q ThemeDemo; then
      MENU="$w"
    fi
  done
  if [ -n "$MENU" ]; then
    eval "$(xwininfo -id "$MENU" | awk '/Absolute upper-left X/ {print "MX=" $NF} /Absolute upper-left Y/ {print "MY=" $NF} /Height:/ {print "MH=" $NF}')"
    CORNER="$(pixel "$MX" $((MY + MH - 1)))"
    INSIDE="$(pixel $((MX + 8)) $((MY + MH - 8)))"
  fi
  xdotool key Escape
  sleep 0.8
  if [ -n "$MENU" ]; then
    BEHIND="$(pixel "$MX" $((MY + MH - 1)))"
  fi
  DETAIL="menu window ${MENU:-none} (32-bit); r+g+b at its bottom left corner ${CORNER:-?}, there without the menu ${BEHIND:-?}, inside ${INSIDE:-?}"
  if [ -n "$MENU" ] && [ "$CORNER" -ge $((BEHIND - 12)) ] && [ "$CORNER" -le $((BEHIND + 12)) ] \
    && [ "$INSIDE" -ge 700 ]; then
    report PASS "$NAME-menu-corners" "$DETAIL"
  else
    report FAIL "$NAME-menu-corners" "$DETAIL"
  fi
fi

BEFORE="$(geometry)"
read -r PX PY <<<"$(bar_point)"
xdotool mousemove "$PX" "$PY" click --repeat 2 --delay 120 1
sleep 1.5
STATE="$(xprop -id "$WINDOW" _NET_WM_STATE)"
MAXIMISED="$(geometry)"
if echo "$STATE" | grep -q MAXIMIZED_VERT && echo "$STATE" | grep -q MAXIMIZED_HORZ; then
  report PASS "$NAME-maximise" "$BEFORE -> $MAXIMISED, maximised by Mutter"
else
  report FAIL "$NAME-maximise" "$BEFORE -> $MAXIMISED; $STATE"
fi

if [ "$SHADOW" = YES ]; then
  # No margin and square corners, as libadwaita's.
  EXTENTS="$(extents)"
  read -r VX VY VW VH <<<"$(visible)"
  CORNER="$(pixel "$VX" "$VY")"
  if [ "$EXTENTS" = "0 0 0 0" ] && [ "$CORNER" -ge 700 ]; then
    report PASS "$NAME-maximised-flat" "frame extents $EXTENTS, top left corner r+g+b $CORNER"
  else
    report FAIL "$NAME-maximised-flat" "frame extents $EXTENTS, top left corner r+g+b $CORNER"
  fi
fi

read -r PX PY <<<"$(bar_point)"
xdotool mousemove "$PX" "$PY" click --repeat 2 --delay 120 1
sleep 1.5
STATE="$(xprop -id "$WINDOW" _NET_WM_STATE)"
AFTER="$(geometry)"
EXTENTS="$(extents)"
if ! echo "$STATE" | grep -q MAXIMIZED && [ "$AFTER" = "$BEFORE" ] \
  && { [ "$SHADOW" = NO ] || [ "$EXTENTS" = "30 30 24 36" ]; }; then
  report PASS "$NAME-restore" "back to $AFTER, frame extents $EXTENTS"
else
  report FAIL "$NAME-restore" "$AFTER (was $BEFORE), frame extents $EXTENTS; $STATE"
fi

# A drag on the bar, 350px to the left: Mutter moves the window, past the
# screen's edge.
read -r VX VY VW VH <<<"$(visible)"
xdotool mousemove "$((VX + 130))" "$((VY + 20))"; sleep 0.3; xdotool mousedown 1; sleep 0.2
for _ in $(seq 1 35); do xdotool mousemove_relative -- -10 0; sleep 0.02; done
sleep 0.3; xdotool mouseup 1; sleep 1
MOVED="$(geometry)"
read -r VX VY VW VH <<<"$(visible)"
if [ "$VX" -lt 0 ]; then
  report PASS "$NAME-move" "$AFTER -> $MOVED, past the left edge"
else
  report FAIL "$NAME-move" "$AFTER -> $MOVED (not moved past the left edge: the move wasn't handed to Mutter)"
fi

# A drag on the right edge, 100px: Mutter widens the window. With a shadow
# the edge is the band outside the window, 6px out.
read -r VX VY VW VH <<<"$(visible)"
if [ "$SHADOW" = YES ]; then
  EDGE_X=$((VX + VW - 1 + 6))
else
  EDGE_X=$((VX + VW - 2))
fi
OLD_WIDTH=$VW
xdotool mousemove "$EDGE_X" "$((VY + VH / 2))"; sleep 0.3; xdotool mousedown 1; sleep 0.2
for _ in $(seq 1 20); do xdotool mousemove_relative -- 5 0; sleep 0.02; done
sleep 0.3; xdotool mouseup 1; sleep 1
read -r VX VY VW VH <<<"$(visible)"
if [ "$VW" -ge $((OLD_WIDTH + 80)) ]; then
  report PASS "$NAME-resize" "width $OLD_WIDTH -> $VW"
else
  report FAIL "$NAME-resize" "width $OLD_WIDTH -> $VW"
fi

if [ "$SHADOW" = YES ]; then
  # Inside the edge, the content's: a drag there doesn't resize.
  read -r VX VY VW VH <<<"$(visible)"
  OLD_WIDTH=$VW
  drag $((VX + VW - 3)) $((VY + VH / 2)) 5 0
  read -r VX VY VW VH <<<"$(visible)"
  if [ "$VW" = "$OLD_WIDTH" ]; then
    report PASS "$NAME-inside-edge" "width $OLD_WIDTH after a drag 3px inside the right edge"
  else
    report FAIL "$NAME-inside-edge" "width $OLD_WIDTH -> $VW after a drag 3px inside the right edge"
  fi

  # The band is the window's; further out, presses go to what is behind.
  read -r VX VY VW VH <<<"$(visible)"
  IN_BAND="$(window_at $((VX + VW - 1 + 12)) $((VY + VH / 2)))"
  BEYOND="$(window_at $((VX + VW - 1 + 13)) $((VY + VH / 2)))"
  if [ "$IN_BAND" = "$WINDOW" ] && [ "$BEYOND" != "$WINDOW" ]; then
    report PASS "$NAME-click-through" "12px out: the window; 13px out: window $BEYOND behind"
  else
    report FAIL "$NAME-click-through" "12px out: window $IN_BAND, 13px out: window $BEYOND (ThemeDemo is $WINDOW)"
  fi
fi

echo "SUMMARY $NAME failed=$FAILED"
exit "$FAILED"
