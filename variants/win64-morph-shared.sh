#!/bin/bash
# morph-ffmpeg: trimmed GPL build for Morph (shared libs: ffmpeg.exe + ffprobe.exe share one set of DLLs).
source "$(dirname "$BASH_SOURCE")"/windows-install-shared.sh
source "$(dirname "$BASH_SOURCE")"/defaults-gpl-shared.sh
source "$(dirname "$BASH_SOURCE")"/../morph/components.sh
FF_CONFIGURE+=" $(morph_configure_flags)"
