#!/bin/bash
# The FFmpeg components Morph needs (and nothing else). Each list is checked after the build
# against morph/expected/*.txt, so a missing feature fails CI.
#
# Used by Morph (crates/morph-core/src/media): encoders, muxers, the filters in the GIF/VMAF/scale graphs,
# GPU test encodes (lavfi testsrc2 -> *_nvenc/_qsv/_amf -> null), ffprobe JSON.
# Inputs promised in SPEC 4.3/4.4: mp4 mkv mov avi webm wmv flv m4v mpg mpeg ts mts 3gp; mp3 wav flac aac m4a
# ogg opus wma aiff (+ cover art). Test-only: mpeg4/mjpeg/libvpx (VP8) encoders, mpegts muxer, lavfi sources.

MORPH_ENCODERS=(
    libx264 libx265 libsvtav1 libvpx_vp8 libvpx_vp9
    h264_nvenc hevc_nvenc av1_nvenc
    h264_qsv hevc_qsv av1_qsv
    h264_amf hevc_amf av1_amf
    aac libmp3lame libopus libvorbis flac pcm_s16le pcm_s24le
    gif mpeg4 mjpeg png wrapped_avframe subrip srt
)

MORPH_DECODERS=(
    # video
    h264 hevc vp8 vp9 libdav1d mpeg1video mpeg2video mpeg4
    msmpeg4v1 msmpeg4v2 msmpeg4v3 wmv1 wmv2 wmv3 vc1 h263 h263p flv vp6 vp6a vp6f
    mjpeg png bmp gif rawvideo prores dvvideo theora
    # audio
    aac aac_latm mp1 mp2 mp2float mp3 mp3float ac3 eac3 dca truehd mlp flac vorbis opus
    wmav1 wmav2 wmapro wmalossless alac amrnb amrwb nellymoser
    adpcm_ms adpcm_ima_wav adpcm_ima_qt adpcm_swf
    pcm_s8 pcm_u8 pcm_s16le pcm_s16be pcm_s24le pcm_s24be pcm_s32le pcm_s32be
    pcm_f32le pcm_f32be pcm_f64le pcm_f64be pcm_alaw pcm_mulaw pcm_dvd pcm_bluray
    # subtitles (mov_text/text -> srt into MKV)
    mov_text text subrip
)

MORPH_MUXERS=(mp4 mov ipod matroska webm avi gif mp3 wav flac ogg opus adts null mpegts)

MORPH_DEMUXERS=(mov matroska avi asf flv mpegps mpegts mpegvideo mp3 wav flac aac ogg aiff)

MORPH_PARSERS=(
    h264 hevc vp8 vp9 av1 mpeg4video mpegvideo mpegaudio aac aac_latm ac3 flac vorbis opus
    mjpeg png gif bmp vc1 h263 dca mlp dvbsub dvdsub dvd_nav
)

MORPH_BSFS=(
    null aac_adtstoasc h264_mp4toannexb hevc_mp4toannexb extract_extradata
    vp9_superframe vp9_superframe_split av1_frame_split mpeg4_unpack_bframes
)

MORPH_FILTERS=(
    buffer buffersink abuffer abuffersink
    scale format aformat aresample fps split setpts asetpts null anull trim atrim
    transpose hflip vflip rotate crop
    palettegen paletteuse libvmaf
    # lavfi sources (GPU probe + tests)
    testsrc testsrc2 smptebars color sine anoisesrc anullsrc noise
)

MORPH_PROTOCOLS=(file pipe)
MORPH_INDEVS=(lavfi)

morph_configure_flags() {
    local f=(--disable-everything --disable-network --disable-ffplay)
    local x
    for x in "${MORPH_ENCODERS[@]}"; do f+=(--enable-encoder="$x"); done
    for x in "${MORPH_DECODERS[@]}"; do f+=(--enable-decoder="$x"); done
    for x in "${MORPH_MUXERS[@]}"; do f+=(--enable-muxer="$x"); done
    for x in "${MORPH_DEMUXERS[@]}"; do f+=(--enable-demuxer="$x"); done
    for x in "${MORPH_PARSERS[@]}"; do f+=(--enable-parser="$x"); done
    for x in "${MORPH_BSFS[@]}"; do f+=(--enable-bsf="$x"); done
    for x in "${MORPH_FILTERS[@]}"; do f+=(--enable-filter="$x"); done
    for x in "${MORPH_PROTOCOLS[@]}"; do f+=(--enable-protocol="$x"); done
    for x in "${MORPH_INDEVS[@]}"; do f+=(--enable-indev="$x"); done
    echo "${f[*]}"
}
