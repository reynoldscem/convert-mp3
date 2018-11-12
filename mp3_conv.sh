#!/bin/bash

set -o errexit
set -o nounset

BITRATE_THRESHOLD=128
TRANSCODE_BITRATE=64

error() {
  echo "An error has occurred. Terminating"
  exit 1
}

trap error INT TERM EXIT

dest_location=$1

filenames=()
while IFS=  read -r -d $'\0' filename; do
    file_info=$(file -b "$filename")
    bitrate=$(sed 's/.*, \(.*\)kbps.*/\1/' <<< "${file_info}"| tr -d ' ')
    if [ "$bitrate" -eq "$bitrate" ] 2>/dev/null; then
        if [ "$bitrate" -ge "$BITRATE_THRESHOLD" ]; then
            echo "$filename has bitrate $bitrate. Will convert."
            filenames+=("$filename")
        fi
    else
        echo "Expected \"number\" kbps in file string. Got:"
        echo "${file_info}"
        error
    fi

  done < <(find "${PWD}/${dest_location}" -name '*.mp3' -print0)

convert_dir="/tmp/mp3_convert"
convert_func() {
    transcode_bitrate=$1
    convert_dir="$2"
    filename="$3"
    job_id="$4"

    dest_filename="${filename%.*}.opus"

    if [ -f "${dest_filename}" ]; then
        echo "${dest_filename} already exists!"
        return 0
    fi

    echo "Converting ${filename}..."
    ffmpeg -hide_banner -loglevel info \
      -i "${filename}" -codec:a libopus \
      -b:a "${transcode_bitrate}k" "${convert_dir}/${job_id}.opus" && \
      mv "${convert_dir}/${job_id}.opus" "${dest_filename}"

    rm -f "${convert_dir}/${job_id}.opus"
}
export -f convert_func

if [ "${#filenames[@]}" -eq 0 ]; then
    echo "No files to convert!"
else
    rm -rf "$convert_dir"
    mkdir -p "$convert_dir"
    parallel "convert_func ${TRANSCODE_BITRATE} ${convert_dir} {} {%}" ::: "${filenames[@]}"
fi

trap - INT TERM EXIT
exit 0
