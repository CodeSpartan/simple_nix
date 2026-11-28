#!/usr/bin/env bash
# Remove steady background noise (PC fan) from a video's audio.
#
#   scripts/denoise-video.sh <input.mp4> [output.mp4] [noise-start-seconds noise-length-seconds]
#
# Learns a noise profile from a stretch with no speech/game sound (found
# automatically: the longest run of quiet 0.5 s windows), then runs
# highpass 80 Hz + ffmpeg afftdn over the audio. The video stream is copied
# untouched; audio is re-encoded as AAC 256k. The input is never modified.
#
# With several audio tracks (gpu-screen-recorder -a default_output -a default_input)
# only the LAST track (the mic) is cleaned; set TRACK=<n> (0-based) to pick another.
# Tunables: NR (reduction dB, default 40), HP (highpass Hz, default 80).
set -euo pipefail

in=${1:?usage: denoise-video.sh <input> [output] [noise-start noise-length]}
out=${2:-${in%.*}-clean.mp4}
nstart=${3:-}
nlen=${4:-}
NR=${NR:-40}
HP=${HP:-80}

[[ -e $out ]] && { echo "error: $out already exists" >&2; exit 1; }

ntracks=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$in" | wc -l)
(( ntracks > 0 )) || { echo "error: no audio track in $in" >&2; exit 1; }
track=${TRACK:-$((ntracks - 1))}
echo "audio tracks: $ntracks, cleaning track $track"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

ffmpeg -v error -i "$in" -map "0:a:$track" -c:a pcm_f32le "$tmp/a.wav"

if [[ -z $nstart ]]; then
  # RMS per 0.5 s window -> "time level" lines
  ffmpeg -v error -i "$tmp/a.wav" -af "asetnsamples=n=24000,astats=metadata=1:reset=1,ametadata=print:key=lavfi.astats.Overall.RMS_level:file=$tmp/rms.txt" -f null -
  paste - - < "$tmp/rms.txt" | sed -E 's/.*pts_time:([0-9.]+).*RMS_level=(.*)/\1 \2/' \
    | sed '$d' | awk '$2 > -80' > "$tmp/levels.txt"   # drop the partial last window and digital silence
  # quiet = within 6 dB of the quietest window; take the longest such run
  read -r nstart nlen floor < <(awk '
    NR==FNR { if (min=="" || $2<min) min=$2; next }
    $2 < min+6 { if (st=="") st=$1; en=$1+0.5; next }
    { if (st!="" && en-st>best) { best=en-st; bs=st }; st="" }
    END { if (st!="" && en-st>best) { best=en-st; bs=st }; print bs, best, min }
  ' "$tmp/levels.txt" "$tmp/levels.txt")
  echo "noise floor ${floor} dB; quietest stretch: ${nstart}s for ${nlen}s"
  if awk -v l="$nlen" 'BEGIN{exit !(l < 2)}'; then
    echo "error: no quiet stretch >= 2 s found; pass one by hand: $0 $in $out <start> <length>" >&2
    exit 1
  fi
  # trim 0.25 s off each edge so no speech tail gets into the profile
  nstart=$(awk -v s="$nstart" 'BEGIN{print s+0.25}')
  nlen=$(awk -v l="$nlen" 'BEGIN{print l-0.5}')
fi

ffmpeg -v error -ss "$nstart" -t "$nlen" -i "$tmp/a.wav" -c copy "$tmp/noise.wav"
sn_stop=$(awk -v l="$nlen" 'BEGIN{print l-0.3}')

# Prepend the noise sample, let afftdn learn it, then cut it off again.
ffmpeg -v error -i "$tmp/noise.wav" -i "$tmp/a.wav" -i "$in" -filter_complex \
  "[0:a][1:a]concat=n=2:v=0:a=1,highpass=f=$HP,asendcmd=c='0.2 afftdn sn start; $sn_stop afftdn sn stop',afftdn=nr=$NR:nf=-80:tn=1,atrim=start=$nlen,asetpts=N/SR/TB[clean]" \
  -map 2:v? -map 2:a -map -2:a:"$track" -map "[clean]" \
  -c:v copy -c:a aac -b:a 256k -movflags +faststart "$out"

lvl() { ffmpeg -hide_banner -ss "$2" -t "$3" -i "$1" -vn -af astats=measure_perchannel=none -f null - 2>&1 \
          | grep -m1 'RMS level' | awk '{print $NF}'; }
after_track=$((ntracks - 1))   # cleaned track is appended last
ffmpeg -v error -i "$out" -map "0:a:$after_track" -c:a pcm_f32le "$tmp/b.wav"
echo "noise stretch level: before $(lvl "$tmp/a.wav" "$nstart" "$nlen") dB, after $(lvl "$tmp/b.wav" "$nstart" "$nlen") dB"
echo "wrote $out"
