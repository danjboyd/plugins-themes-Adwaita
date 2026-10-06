#!/usr/bin/env python3
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

# Which ports `apt-portstree build` would build along with the theme:
# apt-portstree builds a port's dependency ports first and rebuilds any
# whose recorded version or source revision differs from what it resolves
# now (a branch that moved, a tag recorded as its tag object), publishing
# them over the old files under the same version. Read-only. See
# Docs/RELEASING.md. Run on iep-apt:
#
#   ssh iep-apt 'cd ~/git/apt_portstree && python3 -' < Tools/apt-rebuild-check.py
#   ssh iep-apt 'cd ~/git/apt_portstree && python3 - arm64' < Tools/apt-rebuild-check.py
#
# Exits 1 when a port other than the theme would be built.

import json
import subprocess
import sys
import tomllib

THEME = "gnustep/themes/gnustep-clang-themes-adwaita"
ARCH = sys.argv[1] if len(sys.argv) > 1 else "amd64"


def remote_revision(source):
    """The commit a build would use, as apt-portstree resolves it."""
    if "ref" in source:
        return source["ref"]
    if "tag" in source:
        refs = ["refs/tags/" + source["tag"] + "^{}", "refs/tags/" + source["tag"]]
    else:
        refs = ["refs/heads/" + source.get("branch", "master")]
    out = subprocess.run(["git", "ls-remote", source["url"]] + refs,
                         capture_output=True, text=True, check=True).stdout
    found = dict(reversed(line.split("\t")) for line in out.splitlines() if "\t" in line)
    for ref in refs:
        if ref in found:
            return found[ref]
    return None


def main():
    state = json.load(open("var/build_state.json"))
    order, todo = [], [THEME]
    while todo:
        port = todo.pop()
        if port in order:
            continue
        order.append(port)
        manifest = tomllib.load(open(f"ports/{port}/Build.toml", "rb"))
        todo += manifest.get("deps", {}).get("ports", [])

    others = 0
    for port in order:
        manifest = tomllib.load(open(f"ports/{port}/Build.toml", "rb"))
        record = state.get(f"{port}::{ARCH}", {})
        revision = remote_revision(manifest["source"])
        reasons = []
        if record.get("version") != manifest["version"]:
            reasons.append(f"version {record.get('version')} -> {manifest['version']}")
        if revision is None:
            reasons.append("revision not found upstream")
        elif record.get("source_rev") != revision:
            reasons.append(f"revision {record.get('source_rev', 'none')[:10]} -> {revision[:10]}")
        verdict = "BUILD " if reasons else "skip  "
        print(f"{verdict}{port} ({ARCH}){': ' + '; '.join(reasons) if reasons else ''}")
        if reasons and port != THEME:
            others += 1
    if others:
        print(f"\n{others} port(s) other than the theme would be rebuilt and republished. "
              "Don't run apt-portstree; see Docs/RELEASING.md.")
    return 1 if others else 0


sys.exit(main())
