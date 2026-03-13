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
GNUSTEP_SH="/usr/GNUstep/System/Library/Makefiles/GNUstep.sh"

if [ -f "$GNUSTEP_SH" ]; then
  set +u
  # shellcheck disable=SC1090
  . "$GNUSTEP_SH"
  set -u
fi

cd "$REPO_DIR"

make
make demo

defaults write ThemeDemo GSTheme Adwaita
defaults delete ThemeDemo GSScaleFactor >/dev/null 2>&1 || true
defaults delete ThemeDemo GSWindowManagerHandlesDecorations >/dev/null 2>&1 || true
openapp Examples/ThemeDemo/ThemeDemo.app "$@"
