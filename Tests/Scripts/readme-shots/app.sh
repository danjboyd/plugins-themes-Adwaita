#!/bin/bash
# app.sh WORKDIR GNUstep|Adwaita COMMAND...: runs a GNUstep app in the session
# with that theme (Adwaita: this repository's build) and empty defaults.
W=$1; THEME=$2; shift 2
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
[ "$THEME" = Adwaita ] && THEME=$REPO/Adwaita.theme
. /usr/GNUstep/System/Library/Makefiles/GNUstep.sh
export DISPLAY=":$(cat "$W/display")" GNUSTEP_CONFIG_FILE=$W/GNUstep.conf \
  GSETTINGS_BACKEND=keyfile XDG_CONFIG_HOME=$W/gs
exec "$@" -GSTheme "$THEME"
