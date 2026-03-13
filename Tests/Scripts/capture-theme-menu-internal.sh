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

set -eu

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT=""
MENU="demo"
HIGHLIGHT="-1"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --menu)
      MENU="$2"
      shift 2
      ;;
    --highlight)
      HIGHLIGHT="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$OUTPUT" ]; then
  echo "--output is required" >&2
  exit 2
fi

mkdir -p "$(dirname "$OUTPUT")"

set +u
. /usr/GNUstep/System/Library/Makefiles/GNUstep.sh
set -u

defaults write ThemeDemo GSTheme Adwaita
defaults delete ThemeDemo GSScaleFactor >/dev/null 2>&1 || true
defaults delete ThemeDemo GSWindowManagerHandlesDecorations >/dev/null 2>&1 || true

APP="$REPO_DIR/Examples/ThemeDemo/ThemeDemo.app/ThemeDemo"
if [ ! -x "$APP" ]; then
  APP="$HOME/GNUstep/Applications/ThemeDemo.app/ThemeDemo"
fi

"$APP" --capture-menu "$MENU" \
       --capture-menu-output "$OUTPUT" \
       --capture-menu-highlight "$HIGHLIGHT"
