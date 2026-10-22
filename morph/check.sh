#!/bin/bash
# Checks a morph-ffmpeg build (run on Windows, e.g. Git Bash on windows-latest):
#  1. the component lists match morph/expected/*.txt exactly (missing or extra = failure);
#  2. smoke tests run every feature Morph uses (no GPU: GPU encoders are only list-checked).
# Usage: morph/check.sh <folder with ffmpeg.exe + ffprobe.exe> [--update-expected]
set -eo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$(cd "$1" && pwd)"
FF="$BIN/ffmpeg.exe"
FP="$BIN/ffprobe.exe"
EXP="$HERE/expected"
OUT="$(mktemp -d)"
trap 'rm -rf -- "$OUT"' EXIT
FAIL=0

lst() { # kind -> sorted names
    case "$1" in
    filters) "$FF" -hide_banner -filters | sed -n '/^ *------/,$p' | tail -n +2 | awk '{print $2}' ;;
    bsfs) "$FF" -hide_banner -bsfs | tail -n +2 | awk '{print $1}' ;;
    protocols) "$FF" -hide_banner -protocols | awk '/^Input:/{m="in:";next} /^Output:/{m="out:";next} {print m $1}' ;;
    *) "$FF" -hide_banner -"$1" | sed -n '/^ *-\{2,\}/,$p' | tail -n +2 | awk '{print $2}' ;;
    esac | tr -d '\r' | sort
}

for k in encoders decoders muxers demuxers filters bsfs protocols devices; do
    lst "$k" > "$OUT/$k.txt"
    [[ -n "$CHECK_LISTS_DIR" ]] && mkdir -p "$CHECK_LISTS_DIR" && cp "$OUT/$k.txt" "$CHECK_LISTS_DIR/"
    if [[ "$2" == "--update-expected" ]]; then
        cp "$OUT/$k.txt" "$EXP/$k.txt"
    elif ! diff -u "$EXP/$k.txt" "$OUT/$k.txt"; then
        echo "::error::$k differ from morph/expected/$k.txt (- expected, + built)"
        FAIL=1
    else
        echo "$k: OK ($(wc -l < "$OUT/$k.txt"))"
    fi
done

"$FF" -hide_banner -version | head -n 3
cd "$OUT"
run() { # name, args...
    local name="$1"; shift
    if "$FF" -hide_banner -nostdin -y -v error "$@" > "$name.log" 2>&1; then
        echo "ok    $name"
    else
        echo "::error::smoke test '$name' failed"; cat "$name.log"; FAIL=1
    fi
}
V=(-f lavfi -i "testsrc2=d=2:s=320x240:r=25" -f lavfi -i "sine=frequency=440:duration=2")
run h264_aac_mp4  "${V[@]}" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart -f mp4 file:a.mp4
run x265_mp4      "${V[@]}" -c:v libx265 -preset ultrafast -x265-params log-level=error -tag:v hvc1 -c:a aac -f mp4 file:b.mp4
run svtav1_mkv    "${V[@]}" -c:v libsvtav1 -preset 8 -crf 35 -c:a libopus -b:a 96k -f matroska file:c.mkv
run vp9_webm      "${V[@]}" -c:v libvpx-vp9 -deadline good -cpu-used 4 -row-mt 1 -crf 33 -b:v 0 -c:a libopus -f webm file:d.webm
run vp8_webm      "${V[@]}" -c:v libvpx -deadline realtime -c:a libvorbis -f webm file:e.webm
run mpeg4_avi     "${V[@]}" -c:v mpeg4 -q:v 5 -c:a libmp3lame -f avi file:f.avi
run h264_mpegts   "${V[@]}" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac -f mpegts file:g.mts
run x264_pass1    "${V[@]}" -map 0:v -c:v libx264 -b:v 300k -pass 1 -passlogfile p -an -f null -
run x264_pass2    "${V[@]}" -map 0:v -map 1:a -c:v libx264 -b:v 300k -pass 2 -passlogfile p -c:a aac -f mp4 file:h.mp4
run remux_ts_mp4  -i file:g.mts -map 0 -c copy -movflags +faststart -f mp4 file:i.mp4
run remux_mkv     -i file:a.mp4 -map 0 -c copy -f matroska file:j.mkv
run rotate_tag    -display_rotation 90 -i file:a.mp4 -c copy -f mp4 file:rot.mp4
run autorotate    -i file:rot.mp4 -c:v libx264 -preset ultrafast -an -f mp4 file:rot2.mp4
run scale_seek    -ss 0.5 -t 1 -i file:b.mp4 -vf "scale=-2:'min(ih,120)'" -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac -ar 48000 -ac 1 -f mp4 file:k.mp4
run gif           -ss 0 -t 1.5 -i file:a.mp4 -an -sn -dn -vf "fps=15,scale='min(160,iw)':-2:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle" -loop 0 -f gif file:l.gif
run vmaf          -i file:b.mp4 -i file:a.mp4 -lavfi "[0:v]scale=320:240:flags=bicubic,format=yuv420p,setpts=PTS-STARTPTS[d];[1:v]format=yuv420p,setpts=PTS-STARTPTS[r];[d][r]libvmaf=n_threads=2:shortest=1:log_fmt=json:log_path=vmaf.json" -an -f null -
if grep -q '"pooled_metrics"' vmaf.json 2>/dev/null && grep -A3 '"vmaf"' vmaf.json | grep -q '"mean"'; then echo "ok    vmaf_json (built-in model)"; else echo "::error::no VMAF score in vmaf.json"; FAIL=1; fi
run sources       -f lavfi -i "smptebars=s=320x240:r=25:d=1" -f lavfi -i "anoisesrc=d=1:c=pink:a=0.3:r=44100" -f lavfi -i "testsrc=d=1:s=160x120" -vf noise=alls=20:allf=t -map 0:v -map 1:a -c:v libx264 -preset ultrafast -c:a pcm_s16le -f avi file:m.avi
A=(-f lavfi -i "sine=frequency=440:duration=2")
run mp3_cover     "${A[@]}" -f lavfi -i "color=c=red:s=64x64:d=0.04" -map 0:a -map 1:v -frames:v 1 -c:a libmp3lame -b:a 128k -c:v mjpeg -disposition:v attached_pic -metadata title=T -id3v2_version 3 -f mp3 file:n.mp3
run mp3_to_m4a    -i file:n.mp3 -map 0:0 -map 0:1 -c:v copy -disposition:v:0 attached_pic -map_metadata 0 -map_chapters -1 -c:a aac -b:a 192k -f ipod file:o.m4a
run mp3_to_flac   -i file:n.mp3 -map 0:0 -map 0:1 -c:v copy -disposition:v:0 attached_pic -map_metadata 0 -c:a flac -f flac file:p.flac
run to_wav24      "${A[@]}" -c:a pcm_s24le -f wav file:q.wav
run to_ogg        -i file:q.wav -c:a libvorbis -b:a 128k -f ogg file:r.ogg
run to_opus       -i file:q.wav -c:a libopus -b:a 96k -ar 48000 -f opus file:s.opus
run to_mp3_vbr    -i file:p.flac -vn -c:a libmp3lame -q:a 2 -id3v2_version 3 -f mp3 file:t.mp3
run aac_adts      -i file:o.m4a -vn -c:a copy -f adts file:u.aac
run aac_to_m4a    -i file:u.aac -c:a copy -f ipod file:v.m4a
for f in a.mp4 b.mp4 c.mkv d.webm e.webm f.avi g.mts h.mp4 i.mp4 j.mkv rot2.mp4 k.mp4 l.gif m.avi n.mp3 o.m4a p.flac q.wav r.ogg s.opus t.mp3 u.aac v.m4a; do
    run "decode_$f" -i "file:$f" -f null -
    if "$FP" -hide_banner -v error -show_format -show_streams -of json "file:$f" > "$f.json" && grep -q '"codec_name"' "$f.json"; then :; else echo "::error::ffprobe failed on $f"; FAIL=1; fi
done
grep -q '"attached_pic": 1' n.mp3.json && grep -q '"attached_pic": 1' o.m4a.json && grep -q '"attached_pic": 1' p.flac.json \
    && echo "ok    cover art kept (mp3, m4a, flac)" || { echo "::error::cover art missing"; FAIL=1; }
grep -q '"width": 240' rot2.mp4.json && echo "ok    autorotate (320x240 -> 240x320)" || { echo "::error::autorotate did not transpose"; FAIL=1; }
for enc in h264_nvenc hevc_nvenc av1_nvenc h264_qsv hevc_qsv av1_qsv h264_amf hevc_amf av1_amf; do
    grep -qx "$enc" encoders.txt || { echo "::error::GPU encoder $enc missing"; FAIL=1; }
done
exit $FAIL
