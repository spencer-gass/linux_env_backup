#!/usr/bin/env bash
#
# Control the IP traffic generator

set -Eeuo pipefail

readonly AVMM="${AVMM:-/usr/bin/avmm}"

continous_start_flag=false
continous_stop_flag=false

OFFSET="0x6300"
shaper_dec=""

declare -r -A REG_OFFSETS=(
    ["in"]=16
    ["shaper_dec0"]=17
    ["shaper_dec1"]=18
    ["shaper_dec2"]=19
    ["shaper_dec3"]=20
)

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] shaper_dec

Connect a blade ethernet interface to an MPCU ethernet interface.

Available options:

-h, --help              Print this help and exit

[shaper_dec]            shaper rate in bytes per cycle. 0 to 15
                            One of: 0, 1

EOF
    exit
}

parse_params() {
    while :; do
        case "${1-}" in
            -h | --help) usage ;;
            -?*)
                echo "Unknown option: ${1}"
                exit 1;;
            *) break ;;
        esac
        shift
    done

    args=("$@")

    if (( ${#args[@]} < 1 )); then
        echo "Missing arguments. Use -h for help."
        exit 1
    fi

    readonly shaper_dec="${args[0]}"
    valid_shaper_dec=false
    if ((shaper_dec >= 0 && shaper_dec <= 15 )); then
	valid_shaper_dec=true
    fi

    if [[ "${valid_shaper_dec}" == false ]]; then
        echo "Invalid shaper rate: ${shaper_dec}. Must be between 0 and 15."
        exit 1
    fi

    return 0
}

parse_params "$@"

"${AVMM}" write "$OFFSET" "${REG_OFFSETS[${shaper_dec0}]}" "$shaper_dec" >/dev/null
"${AVMM}" write "$OFFSET" "${REG_OFFSETS[${shaper_dec1}]}" "$shaper_dec" >/dev/null
"${AVMM}" write "$OFFSET" "${REG_OFFSETS[${shaper_dec2}]}" "$shaper_dec" >/dev/null
"${AVMM}" write "$OFFSET" "${REG_OFFSETS[${shaper_dec3}]}" "$shaper_dec" >/dev/null

echo Done.
