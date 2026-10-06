# Releasing the theme

How a version of the theme gets from `main` to the apt repo, for amd64 and
arm64. Worked out releasing 0.1.0-alpha4 (2026-10-06); follow it as written.

## The machines

| Machine | What it does |
|---|---|
| this machine | the theme's repo, the local install, `~/git/apt_portstree` for editing the port |
| `iep-apt` | serves the repo (`http://iep-apt/apt-repo`, files in `/var/www/html/apt-repo`), signs the index, builds amd64 |
| `iep-wellproduction` | arm64 (aarch64) machine: builds arm64 |

Both build machines have the GNUstep build dependencies installed from the
repo (`dpkg-checkbuilddeps` passes), so each builds the theme directly with
`dpkg-buildpackage`, natively. No containers and no `apt-portstree build`.

## Two things not to do

- **Don't run `apt-portstree build` for the theme.** It builds the theme's
  dependency ports first and rebuilds any whose recorded revision differs
  from what it resolves now: gnustep-make and libs-base follow upstream
  `master`, and libdispatch's tag is recorded as the tag object, not the
  commit. The rebuilds are published **over the existing files under the
  same version**. On 2026-10-06 this replaced the amd64 gnustep-make,
  libdispatch and libs-base packages; only libs-base could be restored. It
  has no option to skip dependencies. `Tools/apt-rebuild-check.py` shows what
  it would build (below); only use it if that lists nothing but the theme.
- **Don't use the arm64 container on `iep-apt`** (`--container
  debian-trixie-arm64`): arm64 emulation isn't registered there, and it
  fails with `exec format error` and then `apt-get update ... failed`.
  Don't run apt-portstree on `iep-wellproduction` either: its checkout and
  build records are months old, so it would rebuild everything.

## Steps

Set the version once (the tag uses `-alpha4`; Debian uses `~alpha4`):

```sh
V=0.1.0-alpha5            # the tag and GSThemeVersion
DV=0.1.0~alpha5           # the Debian version, without the -1 revision
```

### 1. Check

```sh
make check-quirks
make check-file-chooser
```

Both must pass. Add the suites for whatever changed (`check-mutter`,
`check-mutter-shadow`, `check-wms`).

### 2. Version, tag, push

`VERSION` in `GNUmakefile` and `GSThemeVersion` in
`Resources/Info-gnustep.plist`:

```sh
sed -i "s/^VERSION = .*/VERSION = $V/" GNUmakefile
sed -i "s/GSThemeVersion = \".*\";/GSThemeVersion = \"$V\";/" Resources/Info-gnustep.plist
git commit -am "Version $V"
git tag -a "$V" -m "$V"          # annotated, as the earlier tags
git push origin main "$V"
```

### 3. Install here

```sh
make && make install GNUSTEP_INSTALLATION_DOMAIN=USER
grep GSThemeVersion ~/GNUstep/Library/Themes/Adwaita.theme/Resources/Info-gnustep.plist
```

### 4. The port

In `~/git/apt_portstree` on this machine: `version` and `tag` in
`ports/gnustep/themes/gnustep-clang-themes-adwaita/Build.toml`, and a new
entry at the top of
`packaging/gnustep/themes/gnustep-clang-themes-adwaita/debian/changelog`
(`DV-1`, distribution `trixie`, the date from `date -R`). Check `Recommends`
in `debian/control` if the theme needs newer patched libs-back or libs-gui.
Commit as `gnustep-clang-themes-adwaita DV-1` and push.

On `iep-apt`, bring its checkout up to date. It has uncommitted local
changes (arm64 parity work); leave them alone, a fast-forward doesn't touch
them:

```sh
ssh iep-apt 'cd ~/git/apt_portstree && git pull --ff-only'
```

### 5. Build amd64 on iep-apt

```sh
ssh iep-apt "set -e; rm -rf ~/build-adwaita && mkdir ~/build-adwaita && cd ~/build-adwaita &&
  git clone -q --depth 1 --branch $V https://github.com/danjboyd/plugins-themes-Adwaita.git src &&
  cp -r ~/git/apt_portstree/packaging/gnustep/themes/gnustep-clang-themes-adwaita/debian src/ &&
  cd src && dpkg-checkbuilddeps &&
  DEB_BUILD_OPTIONS=parallel=4 dpkg-buildpackage -us -uc -b > ../build.log 2>&1 && ls ../*.deb"
```

### 6. Build arm64 on iep-wellproduction

The packaging comes from this machine (its own apt_portstree is old):

```sh
ssh iep-wellproduction "set -e; rm -rf ~/build-adwaita && mkdir ~/build-adwaita &&
  git clone -q --depth 1 --branch $V https://github.com/danjboyd/plugins-themes-Adwaita.git ~/build-adwaita/src"
scp -qr ~/git/apt_portstree/packaging/gnustep/themes/gnustep-clang-themes-adwaita/debian \
  iep-wellproduction:build-adwaita/src/
ssh iep-wellproduction "set -e; cd ~/build-adwaita/src && dpkg-checkbuilddeps &&
  DEB_BUILD_OPTIONS=parallel=4 dpkg-buildpackage -us -uc -b > ../build.log 2>&1 && ls ../*.deb"
```

`dpkg-shlibdeps` warns about diversions and `libBlocksRuntime.so`; those
warnings are normal.

### 7. Check the packages

For each architecture, compare with the previous release: the same
`Depends` (unless the theme's libraries changed), the new version inside,
and the binary built from the tag.

```sh
ssh iep-wellproduction "cd ~/build-adwaita && dpkg-deb -f gnustep-clang-themes-adwaita_$DV-1_arm64.deb Version Depends Recommends &&
  dpkg-deb --fsys-tarfile gnustep-clang-themes-adwaita_$DV-1_arm64.deb | tar xO --wildcards '*Info-gnustep.plist' | grep GSThemeVersion"
```

(The same on `iep-apt` with `_amd64`.)

### 8. Publish

Each build gives four files: the `.deb`, the `-dbgsym` `.deb`, `.changes`
and `.buildinfo`. They go into the theme's directory in the pool. Make sure
none of them is there yet: a new version never replaces a file.

```sh
POOL=/var/www/html/apt-repo/pool/main/gnustep/themes/gnustep-clang-themes-adwaita
ssh iep-apt "ls $POOL | grep -F '$DV-1' || echo none yet"

# amd64: already on iep-apt
ssh iep-apt "cp -n ~/build-adwaita/*_$DV-1_amd64.* $POOL/"

# arm64: through this machine
mkdir -p /tmp/adwaita-arm64 && scp -q "iep-wellproduction:build-adwaita/*_$DV-1_arm64.*" /tmp/adwaita-arm64/
scp -q /tmp/adwaita-arm64/* iep-apt:$POOL/ && rm -r /tmp/adwaita-arm64

# The index, signed, for both architectures
ssh iep-apt "cd ~/git/apt_portstree && ARCHS='amd64 arm64' ./scripts/update-release.sh /var/www/html/apt-repo trixie main"
```

### 9. Verify

```sh
for a in amd64 arm64; do
  curl -s http://iep-apt/apt-repo/dists/trixie/main/binary-$a/Packages |
    awk '/^Package: /{n=$2} n=="gnustep-clang-themes-adwaita" && /^Version:/{print a, $2}' a=$a
done
sudo apt update && apt-cache policy gnustep-clang-themes-adwaita
```

Both architectures list the new version, and `apt update` reports no
errors.

## If apt-portstree is used anyway

Only if the check lists nothing but the theme:

```sh
ssh iep-apt 'cd ~/git/apt_portstree && python3 -' < Tools/apt-rebuild-check.py
ssh iep-apt 'cd ~/git/apt_portstree && python3 - arm64' < Tools/apt-rebuild-check.py
```

It exits 1 and names the ports when anything else would be rebuilt. The
direct builds above don't record anything in apt-portstree's
`var/build_state.json`, so after one the check shows the theme itself as
`BUILD`; that's expected.

## If something goes wrong

- Back up first anything a step could overwrite: the files in the pool,
  `/var/www/html/apt-repo/dists`, and `var/build_state.json`.
- An overwritten package can be put back only from a byte-identical copy:
  a machine's `/var/cache/apt/archives`, checked against the SHA256 in an
  older `Packages` index (`/var/lib/apt/lists/iep-apt_apt-repo_*_Packages`
  on a machine that hasn't run `apt update` since). Then run
  `update-release.sh` as in step 8.
- Rebuilt packages from 2026-10-06 are in `~/apt-rebuild-backup-20261006`
  on `iep-apt`; the arm64 pool and index from before alpha4's arm64 build
  are in `~/apt-arm64-backup-20261006`.
