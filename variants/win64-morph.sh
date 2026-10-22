#!/bin/bash
# morph-ffmpeg: same components, static exes (only built on request, to compare sizes).
source "$(dirname "$BASH_SOURCE")"/windows-install-static.sh
source "$(dirname "$BASH_SOURCE")"/defaults-gpl.sh
source "$(dirname "$BASH_SOURCE")"/../morph/components.sh
FF_CONFIGURE+=" $(morph_configure_flags)"
