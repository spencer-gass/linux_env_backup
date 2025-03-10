#!/usr/bin/env bash
#
# Control the IP traffic generator

set -Eeuo pipefail

readonly AVMM="${AVMM:-/usr/bin/avmm}"

continous_start_flag=false
continous_stop_flag=false

declare -r -A OFFSET_MAP=(
    ["0"]="0x5000"
    ["1"]="0x6000"
)

declare -r -A REG_OFFSETS=(
    ["status"]=16
    ["remaining_packets"]=17
    ["remaining_interval"]=18
    ["tx_count0"]=19
    ["tx_count1"]=20
    ["ctrl"]=21
    ["num_packets"]=22
    ["interval"]=23
    ["ip_eth_type"]=24
    ["hdip_dscp"]=25
    ["ip_ecn"]=26
    ["ip_identification"]=27
    ["ip_flags"]=28
    ["ip_fragment_offset"]=29
    ["ip_ttl"]=30
    ["ip_protocol"]=31
    ["ip_source_ip"]=32
    ["ip_dest_ip"]=33
    ["dest_mac_msb"]=34
    ["dest_mac_lsb"]=35
)

declare -r -A REG_VALS=(
    ["ip_eth_type"]=0x806
    ["hdip_dscp"]=0x0
    ["ip_ecn"]=0x0
    ["ip_identification"]=0x0
    ["ip_flags"]=0x2
    ["ip_fragment_offset"]=0x0
    ["ip_ttl"]=0x2
    ["ip_protocol"]=0x1
    ["ip_source_ip"]=0xc0a86d0a
    ["ip_dest_ip"]=0xc0a86d01
    ["dest_mac_msb"]=0xffff
    ["dest_mac_lsb"]=0xffffffff
)


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

if $continous_stop_flag; then
    tx_cnt1=`"${AVMM}" read "${OFFSET_MAP[${gen_inst}]}" "${REG_OFFSETS[tx_count1]}"  | cut  -d" " -f 7`
    tx_cnt1=${tx_cnt1:2:8}
    tx_cnt0=`"${AVMM}" read "${OFFSET_MAP[${gen_inst}]}" "${REG_OFFSETS[tx_count0]}"  | cut  -d" " -f 7`
    tx_cnt0=${tx_cnt0:2:8}
    echo Transmitted Packets: $tx_cnt1$tx_cnt0

    "${AVMM}" write "${OFFSET_MAP[${gen_inst}]}" "${REG_OFFSETS[ctrl]}" 0x0 >/dev/null
    exit;
fi

# set up initial values
for reg_name in "${!REG_VALS[@]}"; do
    "${AVMM}" write "${OFFSET_MAP[${gen_inst}]}" "${REG_OFFSETS[${reg_name}]}" "${REG_VALS[${reg_name}]}" >/dev/null
done


#start sending
if $continous_start_flag; then
# set up configured values
    "${AVMM}" write "${OFFSET_MAP[${gen_inst}]}" "${REG_OFFSETS[num_packets]}" 0x0 >/dev/null
    "${AVMM}" write "${OFFSET_MAP[${gen_inst}]}" "${REG_OFFSETS[interval]}" 0x0 >/dev/null
    "${AVMM}" write "${OFFSET_MAP[${gen_inst}]}" "${REG_OFFSETS[ctrl]}" 0x3 >/dev/null
    "${AVMM}" write "${OFFSET_MAP[${gen_inst}]}" "${REG_OFFSETS[ctrl]}" 0x2 >/dev/null
else
    # set up configured values
    "${AVMM}" write "${OFFSET_MAP[${gen_inst}]}" "${REG_OFFSETS[num_packets]}" ${count} >/dev/null
    "${AVMM}" write "${OFFSET_MAP[${gen_inst}]}" "${REG_OFFSETS[interval]}" ${interval} >/dev/null
    "${AVMM}" write "${OFFSET_MAP[${gen_inst}]}" "${REG_OFFSETS[ctrl]}" 0x1 >/dev/null
    "${AVMM}" write "${OFFSET_MAP[${gen_inst}]}" "${REG_OFFSETS[ctrl]}" 0x0 >/dev/null
fi

#monitor progress

busy_bit=1

while [ $busy_bit -gt 0 ];
do

    if $continous_start_flag; then
        tx_cnt1=`"${AVMM}" read "${OFFSET_MAP[${gen_inst}]}" "${REG_OFFSETS[tx_count1]}"  | cut  -d" " -f 7`
        tx_cnt1=${tx_cnt1:2:8}
        tx_cnt0=`"${AVMM}" read "${OFFSET_MAP[${gen_inst}]}" "${REG_OFFSETS[tx_count0]}"  | cut  -d" " -f 7`
        tx_cnt0=${tx_cnt0:2:8}
        echo Transmitted Packets: $tx_cnt1$tx_cnt0

    else
        status_reg=`"${AVMM}" read "${OFFSET_MAP[${gen_inst}]}" "${REG_OFFSETS[status]}"  | cut  -d" " -f 7`
        status_reg=${status_reg:2:8}
        status_bits=$(echo "obase=2; ibase=16; $status_reg" | bc )
        busy_bit=${status_bits:0:1}

        remaining_packets_reg=`"${AVMM}" read "${OFFSET_MAP[${gen_inst}]}" "${REG_OFFSETS[remaining_packets]}"  | cut  -d" " -f 7`
        remaining_packets_reg=${remaining_packets_reg:2:8}
        remaining_packets=$(echo "obase=10; ibase=16; $remaining_packets_reg" | bc )
        echo Remaining_packets: $remaining_packets
    fi
    sleep 1
done

echo Done.
