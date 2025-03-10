#!/usr/bin/env bash

declare -r -A OFFSET_MAP=(
    ["0"]="0x6400"
    ["1"]="0x6500"
    ["2"]="0x6600"
    ["3"]="0x6700"
    ["4"]="0x6800"
    ["5"]="0x6900"
    ["6"]="0x6A00"
    ["7"]="0x6B00"
    ["8"]="0x6C00"
    ["9"]="0x6D00"
)

for key in "${!OFFSET_MAP[@]}"; do
    value="${OFFSET_MAP[$key]}"
    echo "Key: $key, Value: $value"
done