cdk() {

    KEPLER_SYM_PATH="/home/sgass/Projects/kepler"
    KEPLER_PATH="/mnt/ssd2/Projects/kepler"
    CURRENT_DIR=$(pwd)
    NUM_KEPLER_DIRS=4
    
    # cd to a specified kepler repo directory. 
    if [[ "$1" =~ ^[1-$NUM_KEPLER_DIRS]$ ]]; then
        if [[ $1 == "1" ]]; then
            TARGET_PATH="${KEPLER_SYM_PATH}"
        else
            TARGET_PATH="${KEPLER_SYM_PATH}$1"
        fi
        if [ -d "$TARGET_PATH" ]; then
            cd "$TARGET_PATH"
        fi
    # cd to the top of a kepler repo directory we are already in or
    # cd to ~/Projects/kepler
    else
        #if [[ "$CURRENT_DIR" =~ ^/home/sgass/Projects/kepler([1-4])(/|$) ]]; then
        if [[ "$CURRENT_DIR" =~ ^(${KEPLER_SYM_PATH}|${KEPLER_PATH})([1-${NUM_KEPLER_DIRS}])(/|$) ]]; then
            index="${match[2]}"
            cd "${KEPLER_SYM_PATH}$index"
        else
            cd "$KEPLER_SYM_PATH"
        fi
    fi
}

