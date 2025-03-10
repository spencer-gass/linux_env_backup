#!/usr/bin/env bash
#
# Control the IP traffic generator

continous_start_flag=false
continous_stop_flag=false

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] gen_inst count interval

Connect a blade ethernet interface to an MPCU ethernet interface.

Available options:

-h, --help              Print this help and exit
-v, --verbose           Enable verbose output
-c, --continous         Send packets indefinitielly
-s, --stop              Stop sending packets

[gen_inst]              Which traffic generator to use
                            One of: 0, 1
[count]                 How many packets to send
[interval]              How many 6.4ns periods to wait between packets


EOF
    exit
}

parse_params() {
    while :; do
        case "${1-}" in
            -h | --help) usage ;;
            -v | --verbose) set -x ;;
            -c | --continuous) continous_start_flag=true ;;
            -s | --stop) continous_stop_flag=true ;;
            -?*)
                echo "Unknown option: ${1}"
                exit 1;;
            *) break ;;
        esac
        shift
    done

    args=("$@")

    if (( ${#args[@]} < 3 )); then
        echo "Missing arguments. Use -h for help."
        exit 1
    fi

    readonly gen_inst="${args[0]}"
    valid_gen_inst=false
    for interface in "0" "1"; do
        if [[ "${interface}" == "${gen_inst}" ]]; then
          valid_gen_inst=true
          break
        fi
    done
    if [[ "${valid_gen_inst}" == false ]]; then
        echo "Invalid generator instance ID: ${gen_inst}. Must be 0 or 1."
        exit 1
    fi

    readonly count="${args[1]}"
    valid_count=false
    if ((count >= 1 && count <= 4294967295 )); then
	valid_count=true
    fi

    if [[ "${valid_count}" == false ]]; then
        echo "Invalid count range: ${count}. Should be between 1 and 4294967295"
        exit 1
    fi

    readonly interval="${args[2]}"
    valid_interval=false
    if ((interval >= 1 && interval <= 4294967295 )); then
	valid_interval=true
    fi

    if [[ "${valid_interval}" == false ]]; then
        echo "Invalid interval range: ${interval}. Should be between 1 and 4294967295"
        exit 1
    fi


    return 0
}

parse_params "$@"

echo $continous_start_flag
echo $continous_stop_flag

if $continous_start_flag; then
    echo "Start"
fi

if $continous_stop_flag; then
    echo "Stop"
fi


echo Done.


