#!/bin/bash
# app.sh WORKDIR GNUstep|Adwaita COMMAND...: runs a GNUstep app in the session
# with that theme (Adwaita: this repository's build) and empty defaults.
# Nothing from the desktop's session: not its Wayland display, and not its
# session bus (an address that leads nowhere, and a runtime directory of
# the app's own, as GLib would otherwise find the user bus through
# XDG_RUNTIME_DIR or start one with dbus-launch).
W=$1; THEME=$2; shift 2
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
[ "$THEME" = Adwaita ] && THEME=$REPO/Adwaita.theme
. /usr/GNUstep/System/Library/Makefiles/GNUstep.sh
mkdir -p "$W/apprun"
chmod 700 "$W/apprun"
unset WAYLAND_DISPLAY
export DISPLAY=":$(cat "$W/display")" GNUSTEP_CONFIG_FILE=$W/GNUstep.conf \
  GSETTINGS_BACKEND=keyfile XDG_CONFIG_HOME=$W/gs GDK_BACKEND=x11 \
  XDG_RUNTIME_DIR=$W/apprun DBUS_SESSION_BUS_ADDRESS="unix:path=$W/no-session-bus"
exec "$@" -GSTheme "$THEME"
