#!/bin/bash
# Turns the BtbN build artifact into the morph-ffmpeg release files:
#   dist/morph-ffmpeg-<ver>-win64.zip          ffmpeg.exe, ffprobe.exe, DLLs, LICENSE.txt, licenses/, BUILDINFO.txt
#   dist/morph-ffmpeg-<ver>-source.tar.xz      complete corresponding source (FFmpeg + every library + scripts)
#   dist/SHA256SUMS
# Usage: morph/package.sh <artifact.zip> <release version, e.g. 9.0.2-1>
set -xeo pipefail
cd "$(dirname "$0")/.."
source morph/config.sh

ARTIFACT="$(realpath "$1")"
VER="$2"
NAME="morph-ffmpeg-${VER}"
DIST="$PWD/dist"
WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT
rm -rf "$DIST" && mkdir -p "$DIST"

# ---- binaries ----
unzip -q "$ARTIFACT" -d "$WORK/art"
SRCROOT="$(echo "$WORK"/art/*)"
BIN="$WORK/$NAME-win64"
mkdir -p "$BIN/licenses"
cp "$SRCROOT"/bin/ffmpeg.exe "$SRCROOT"/bin/ffprobe.exe "$BIN"/
cp "$SRCROOT"/bin/*.dll "$BIN"/ 2>/dev/null || true
cp "$SRCROOT"/LICENSE.txt "$BIN"/LICENSE.txt

# ---- sources ----
SRC="$WORK/$NAME-source"
mkdir -p "$SRC/deps"
FFCOMMIT="$(cat "$SRCROOT"/ffmpeg-commit.txt)"
git clone --filter=blob:none --no-checkout https://github.com/FFmpeg/FFmpeg.git "$WORK/ffmpeg-git"
git -C "$WORK/ffmpeg-git" archive --format=tar --prefix="ffmpeg-${FFMPEG_VERSION}/" "$FFCOMMIT" | xz -T0 -6 > "$SRC/ffmpeg-${FFMPEG_VERSION}.tar.xz"
git archive --format=tar --prefix="morph-ffmpeg-build-scripts/" HEAD | xz -T0 -6 > "$SRC/morph-ffmpeg-build-scripts.tar.xz"

DEPLIST=""
for STAGE in $(morph/stages.sh); do
    STAGENAME="$(basename "$STAGE" .sh)"
    # Same name the Dockerfile mounts as the stage's source cache.
    CACHE="$(grep -o "src=${STAGE},dst=/stage.sh --mount=src=[^,]*" Dockerfile | head -n1 | sed 's/.*--mount=src=//')"
    if [[ -z "$CACHE" ]]; then
        echo "$STAGENAME: no download (headers/scripts only)"; continue
    fi
    [[ -f "$CACHE" ]] || { echo "Missing source cache $CACHE"; exit 1; }
    D="$SRC/deps/$STAGENAME"
    mkdir -p "$D"
    tar -xaf "$CACHE" -C "$D"
    # Record the pinned upstream revision before dropping VCS metadata.
    REPO="$(bash -c "source '$STAGE'; echo \"\${SCRIPT_REPO:-}\"")"
    REV="$(bash -c "source '$STAGE'; echo \"\${SCRIPT_COMMIT:-\${SCRIPT_REV:-\${SCRIPT_TAG:-}}}\"")"
    find "$D" -name .git -prune -exec rm -rf {} +
    DEPLIST+="${STAGENAME} ${REPO} @ ${REV}"$'\n'
    # Licence files of each library go next to the binaries.
    L="$BIN/licenses/${STAGENAME#??-}"
    mkdir -p "$L"
    find "$D" -maxdepth 3 -type f \( -iname 'COPYING*' -o -iname 'LICENSE*' -o -iname 'LICENCE*' -o -iname 'PATENTS*' -o -iname 'NOTICE*' \) \
        -not -path '*/test*' -not -path '*/doc/*' -not -path '*/third_party/*' -not -path '*/Thirdparty/*' | while read -r f; do
        rel="${f#"$D"/}"; mkdir -p "$L/$(dirname "$rel")"; cp "$f" "$L/$rel"
    done
done
printf '%s' "$DEPLIST" > "$SRC/deps/VERSIONS.txt"

CONFIGURE_FLAGS="$(grep -o 'FF_CONFIGURE="[^"]*"' Dockerfile | sed 's/^FF_CONFIGURE=//; s/"//g')"
BUILDINFO="morph-ffmpeg ${VER} (win64, shared, GPL-3.0-or-later)
Built for Morph (OpenMorph) by GitHub Actions from https://github.com/${GITHUB_REPOSITORY:-renangomide/morph-ffmpeg}
Build scripts: based on BtbN/FFmpeg-Builds (MIT, https://github.com/BtbN/FFmpeg-Builds), upstream commit 937868360a21d711ec94a33f5591d345ad9b7754
Build scripts commit: $(git rev-parse HEAD)

FFmpeg ${FFMPEG_VERSION} (tag ${FFMPEG_TAG}, commit ${FFCOMMIT}), configured with --enable-gpl --enable-version3: GPL-3.0.
Toolchain images: ${BASE_IMAGE_REF}
                  ${TARGET_BASE_IMAGE_REF}
  (GCC 16.2.0, binutils 2.47, mingw-w64; libgcc/libstdc++ linked statically under the GCC Runtime Library Exception)

Libraries (stage, upstream, revision):
${DEPLIST}
Complete corresponding source: ${NAME}-source.tar.xz, attached to the same release.

FFmpeg configure flags (plus the toolchain/cross flags from build.sh):
${CONFIGURE_FLAGS}
"
printf '%s\n' "$BUILDINFO" > "$BIN/BUILDINFO.txt"
cp "$SRCROOT"/configure.log "$BIN/licenses/configure.log"
cp "$BIN/BUILDINFO.txt" "$SRC/BUILDINFO.txt"
cat > "$SRC/README.txt" <<TXT
Complete corresponding source for ${NAME}-win64.zip.

ffmpeg-${FFMPEG_VERSION}.tar.xz           FFmpeg at tag ${FFMPEG_TAG} (commit ${FFCOMMIT})
morph-ffmpeg-build-scripts.tar.xz   the scripts that built it (variant win64-morph-shared, addin 9.0;
                                    see morph/ and .github/workflows/morph.yml); FFmpeg's configure
                                    flags come from variants/win64-morph-shared.sh + morph/components.sh
                                    + the ffbuild_configure of each stage in scripts.d/
deps/<stage>/                       the exact source of every library linked in (VERSIONS.txt lists
                                    upstream + revision); patches are applied by the stage scripts
To rebuild: extract the build scripts and run their workflow steps (generate.sh, download.sh, docker
buildx, build.sh) on Linux with Docker.
TXT

(cd "$WORK" && zip -q -9 -r "$DIST/$NAME-win64.zip" "$NAME-win64")
tar -C "$WORK" -cf - "$NAME-source" | xz -T0 -6 > "$DIST/$NAME-source.tar.xz"
(cd "$DIST" && sha256sum *.zip *.tar.xz > SHA256SUMS)
ls -la "$DIST" "$BIN"
du -sh "$BIN"
