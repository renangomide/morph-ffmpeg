# morph-ffmpeg

A trimmed GPL build of [FFmpeg](https://ffmpeg.org) for Windows x64, made for **Morph** (OpenMorph), the
right-click file converter. It keeps only what Morph uses: `--disable-everything` plus an explicit list of
encoders, decoders, (de)muxers, parsers, bitstream filters, filters and protocols (`morph/components.sh`),
and only these external libraries: x264, x265, SVT-AV1, libvpx, dav1d, libvmaf (built-in models),
libopus, LAME, libvorbis/libogg, zlib, libiconv, NVENC headers (nv-codec-headers), AMF headers, libvpl (QSV).

## Releases

Tag `v<FFmpeg version>-<rev>` (must match `morph/config.sh`, e.g. `v9.0.2-1`). Each release has:

- `morph-ffmpeg-<ver>-win64.zip`: `ffmpeg.exe`, `ffprobe.exe`, the shared FFmpeg DLLs, `LICENSE.txt` (GPL-3.0),
  `licenses/` (every library's licence files + `configure.log`), `BUILDINFO.txt` (versions, commits, flags).
- `morph-ffmpeg-<ver>-source.tar.xz`: the complete corresponding source: FFmpeg at the tag, every library at
  the pinned revision, and these build scripts.
- `SHA256SUMS`.

## How it builds

`.github/workflows/morph.yml` (Ubuntu runner, Docker cross-compile with mingw-w64):
`generate.sh win64 morph-shared 9.0` → `download.sh` (only the needed stages) → `docker buildx build`
(dependency image) → `build.sh` (FFmpeg, configure must not warn about unknown components) →
`morph/package.sh`. A Windows job then runs `morph/check.sh`: the component lists must equal
`morph/expected/*.txt` exactly, and smoke tests run every feature Morph uses (x264/x265/SVT-AV1/VP9/VP8,
two-pass, remux, autorotate, GIF palette, VMAF JSON with the built-in model, MP3/M4A/FLAC cover art, ...).

To change the feature set: edit `morph/components.sh`, run the workflow, review the `component-lists`
artifact, copy it into `morph/expected/`, commit.

## Credits and licences

The build system is a copy of [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds) (MIT, see `LICENSE`;
upstream README in `README.upstream.md`), with a `morph` variant added. The binaries are GPL-3.0
(FFmpeg configured with `--enable-gpl --enable-version3`).
