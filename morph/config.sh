#!/bin/bash
# morph-ffmpeg build pins. Sourced by the CI workflow and the morph scripts.
# Changing anything here changes the build: bump MORPH_REV (or FFMPEG_VERSION) and tag a new release.

# FFmpeg release (git tag in https://github.com/FFmpeg/FFmpeg).
FFMPEG_VERSION="9.0.2"
FFMPEG_TAG="n${FFMPEG_VERSION}"
# Our build revision for this FFmpeg version. Release tag: v${FFMPEG_VERSION}-${MORPH_REV}.
MORPH_REV="1"

TARGET="win64"
VARIANT="morph-shared"
# BtbN addin that selects the FFmpeg 9.0 code paths in scripts.d (its GIT_BRANCH is overridden below).
ADDIN="9.0"

# Build images (cross toolchain: GCC 16.2.0, binutils 2.47, mingw-w64 v14.0.0; see images/base-win64/ct-ng-config).
# Pinned by digest. These are BtbN's public images built from images/base and images/base-win64 at
# upstream commit 937868360a21d711ec94a33f5591d345ad9b7754.
BASE_IMAGE_REF="ghcr.io/btbn/ffmpeg-builds/base:latest@sha256:91eaaaf32f3f98464e99faf1062fab8ab99a23d0b499c72b51a02ec9137b06a0"
TARGET_BASE_IMAGE_REF="ghcr.io/btbn/ffmpeg-builds/base-win64:latest@sha256:8a3d189e5b615c89e1a9fe2be705fa17173d8f6ea0a955b25c7c28041cde36c7"

export FFMPEG_VERSION FFMPEG_TAG MORPH_REV TARGET VARIANT ADDIN BASE_IMAGE_REF TARGET_BASE_IMAGE_REF
export GIT_BRANCH_OVERRIDE="$FFMPEG_TAG"
