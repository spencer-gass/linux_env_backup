source-vivado() {

    local version=$1

    local vivado_2019_install_dirs=("/opt/Xilinx/Vivado/2019.1/bin" "/opt/Xilinx/SDK/2019.1/bin")
    local vivado_2021_install_dirs=("/opt/Xilinx/Vivado/2021.2/bin" "/opt/Xilinx/Vitis/2021.2/bin")
    local vivado_2022_install_dirs=("/opt/Xilinx/Vivado/2022.1/bin")
    local vivado_2023_install_dirs=("/opt/Xilinx/Vivado/2023.1/bin")
    local vivado_install_dirs=("${vivado_2019_install_dirs[@]}" "${vivado_2021_install_dirs[@]}" "${vivado_2022_install_dirs[@]}" "$vivado_2023_install_dirs[@]")

    # remove existing version of vivado from PATH
    local new_path=""
    local path_dir
    local install_dir
    local is_vivado_dir="false"

    local path_dirs=($(echo "$PATH" | tr ':' ' '))

    for path_dir in "$path_dirs[@]"; do
        is_vivado_dir="false"
        for install_dir in "$vivado_install_dirs[@]"; do
            if [[ "$path_dir" == "$install_dir" ]]; then
                is_vivado_dir="true"
            fi
        done
        if [[ $is_vivado_dir == "false" ]]; then
            new_path="${new_path}${new_path:+:}$path_dir"
        fi
    done

    # Add selected version of vivado to path
    case $version in
        "-h"|"--help")
            echo "Usage: source-vivado [-h|--help] <version>"
            echo
            echo "Example source-vivado 2021"
            echo
            echo "Options:"
            echo "  -h, --help      Show help text"
            echo
            echo "Arguments:"
            echo "  version         Vivado version to load"
            echo "                  Valid options: 2019, 2021, 2022, 2023"
            echo
            ;;
        "2019")
            for install_dir in "$vivado_2019_install_dirs[@]"; do
                new_path=$install_dir:$new_path
            done
            ;;
        "2021")
            for install_dir in "$vivado_2021_install_dirs[@]"; do
                new_path=$install_dir:$new_path
            done
            ;;
        "2022")
            for install_dir in "$vivado_2022_install_dirs[@]"; do
                new_path=$install_dir:$new_path
            done
            ;;
        "2023")
            for install_dir in "$vivado_2023_install_dirs[@]"; do
                new_path=$install_dir:$new_path
            done
            ;;
        *)
            echo "Invalid option. Try source-vivado -h"
            return 1
        ;;
    esac

    export PATH=$new_path

}
