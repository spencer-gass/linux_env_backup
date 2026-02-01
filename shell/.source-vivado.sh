# bash function to set up env for a specified version of Xilinx tools
# required environement variables, install directories to add to PATH
# were aquired from the settings64.sh scripts for the respective tool
# versions.

source-vivado() {

    local version=$1

    local xilinx_2019_install_dirs=(
        "/opt/Xilinx/Vivado/2019.1/bin" 
        "/opt/Xilinx/SDK/2019.1/bin"
    )
    local xilinx_2021_install_dirs=(
        "/opt/Xilinx/Vitis/2021.2/bin" 
        "/opt/Xilinx/Vitis/2021.2/gnu/microblaze/lin/bin"
        "/opt/Xilinx/Vitis/2021.2/gnu/arm/lin/bin"
        "/opt/Xilinx/Vitis/2021.2/gnu/microblaze/linux_toolchain/lin64_le/bin"
        "/opt/Xilinx/Vitis/2021.2/gnu/aarch32/lin/gcc-arm-linux-gnueabi/bin"
        "/opt/Xilinx/Vitis/2021.2/gnu/aarch32/lin/gcc-arm-none-eabi/bin"
        "/opt/Xilinx/Vitis/2021.2/gnu/aarch64/lin/aarch64-linux/bin"
        "/opt/Xilinx/Vitis/2021.2/gnu/aarch64/lin/aarch64-none/bin"
        "/opt/Xilinx/Vitis/2021.2/gnu/armr5/lin/gcc-arm-none-eabi/bin"
        "/opt/Xilinx/Vitis/2021.2/tps/lnx64/cmake-3.3.2/bin"
        "/opt/Xilinx/Vitis/2021.2/aietools/bin"
        "/opt/Xilinx/Vivado/2021.2/bin" 
        "/opt/Xilinx/Vitis_HLS/2021.2/bin" 
    )
    local xilinx_2023_install_dirs=(
        "/opt/Xilinx/Vitis_HLS/2023.2/bin"
        "/opt/Xilinx/Vivado/2023.2/bin"
        "/opt/Xilinx/Model_Composer/2023.2/bin"
        "/opt/Xilinx/Vitis/2023.2/bin"
        "/opt/Xilinx/Vitis/2023.2/gnu/microblaze/lin/bin"
        "/opt/Xilinx/Vitis/2023.2/gnu/microblaze/linux_toolchain/lin64_le/bin"
        "/opt/Xilinx/Vitis/2023.2/gnu/aarch32/lin/gcc-arm-linux-gnueabi/bin"
        "/opt/Xilinx/Vitis/2023.2/gnu/aarch32/lin/gcc-arm-none-eabi/bin"
        "/opt/Xilinx/Vitis/2023.2/gnu/aarch64/lin/aarch64-linux/bin"
        "/opt/Xilinx/Vitis/2023.2/gnu/aarch64/lin/aarch64-none/bin"
        "/opt/Xilinx/Vitis/2023.2/gnu/armr5/lin/gcc-arm-none-eabi/bin"
        "/opt/Xilinx/Vitis/2023.2/tps/lnx64/cmake-3.3.2/bin"
        "/opt/Xilinx/Vitis/2023.2/aietools/bin"
        "/opt/Xilinx/Vitis/2023.2/gnu/riscv/lin/riscv64-unknown-elf/bin"
    )
    local xilinx_2024_install_dirs=(
        "/opt/Xilinx/PDM/2024.2/bin"
        "/opt/Xilinx/Vitis_HLS/2024.2/bin"
        "/opt/Xilinx/Vivado/2024.2/bin"
        "/opt/Xilinx/Vitis/2024.2/bin"
        "/opt/Xilinx/Vitis/2024.2/gnu/microblaze/lin/bin"
        "/opt/Xilinx/Vitis/2024.2/gnu/microblaze/linux_toolchain/lin64_le/bin"
        "/opt/Xilinx/Vitis/2024.2/gnu/aarch32/lin/gcc-arm-linux-gnueabi/bin"
        "/opt/Xilinx/Vitis/2024.2/gnu/aarch32/lin/gcc-arm-none-eabi/bin"
        "/opt/Xilinx/Vitis/2024.2/gnu/aarch64/lin/aarch64-linux/bin"
        "/opt/Xilinx/Vitis/2024.2/gnu/aarch64/lin/aarch64-none/bin"
        "/opt/Xilinx/Vitis/2024.2/gnu/armr5/lin/gcc-arm-none-eabi/bin"
        "/opt/Xilinx/Vitis/2024.2/aietools/bin"
        "/opt/Xilinx/Vitis/2024.2/gnu/riscv/lin/riscv64-unknown-elf/bin"
    )
    local xilinx_install_dirs=(
        "${xilinx_2019_install_dirs[@]}" 
        "${xilinx_2021_install_dirs[@]}" 
        "${xilinx_2023_install_dirs[@]}"
        "${xilinx_2024_install_dirs[@]}" 
    )

    # Function to remove existing Xilinx install directories from $PATH
    # This keeps $PATH from getting cluttered if you switch between versions
    rm_xilinx_dirs_from_path(){
        local path_dirs=($(echo "$PATH" | tr ':' ' '))
        local new_path=""
        local is_xilinx_dir="false"
        for path_dir in "${path_dirs[@]}"; do            
            is_xilinx_dir="false"
            for xilinx_dir in "${xilinx_install_dirs[@]}"; do
                if [[ "$path_dir" == "$xilinx_dir" ]]; then
                    is_xilinx_dir="true"
                    break
                fi
            done
            if [[ $is_xilinx_dir == "false" ]]; then
                new_path="${new_path}${new_path:+:}${path_dir}"
            fi
        done
        PATH="$new_path"
    }

    # Function to add an array of install directory path strings to $PATH
    add_to_path(){
        local paths_to_add=("$@")
        for install_dir in "${paths_to_add[@]}"; do
            # If PATH is empty then don't add a colon
            PATH=$install_dir${PATH:+:}$PATH
        done
    }

    # Function to clean $PATH, then add requested Xilinx install dirs
    update_path(){
        local install_dirs=("$@")
        rm_xilinx_dirs_from_path
        add_to_path "$install_dirs[@]"
    }

    # Function to remove an entry from $PYTHONPATH
    # This prevents $PYTHONPATH from getting cluttered.
    rm_from_py_path(){
        local path_to_rm=$1
        local new_path=""
        local py_path_dirs=($(echo "$PYTHONPATH" | tr ':' ' '))
        for path_dir in "${py_path_dirs[@]}"; do
            if [[ "$path_dir" != "$path_to_rm" ]]; then
                new_path="${new_path}${new_path:+:}$path_dir"
            fi
        done
        PYTHONPATH="$new_path"
    }

    # Add a directory string to $PYTHONPATH
    add_to_py_path(){
        local py_path=$1
        # If PYTHONPATH is empty then don't add a colon
        export PYTHONPATH="${py_path}${PYTHONPATH:+:}${PYTHONPATH}"
    }

    # Unlike $PATH, there aren't as many directories to add so to simplfy,
    # remove the requested entry and add it to the begining of $PYTHONPATH 
    update_py_path(){
        local py_path=$1
        rm_from_py_path "$py_path"
        add_to_py_path  "$py_path"
    }
    
    # Handle arguments and set up env accordingly.
    case $version in
        "-h"|"--help")
            echo "Usage: source-vivado [-h|--help] <version>"
            echo
            echo "Example: source-vivado 2021"
            echo
            echo "Options:"
            echo "  -h, --help      Show help text"
            echo
            echo "Arguments:"
            echo "  version         Vivado version to load"
            echo "                  Valid options: 2019, 2021, 2024"
            echo
            ;;
        "2019")
            export XILINX_VIVADO=/opt/Xilinx/Vivado/2019.1
            export XILINX_HLS=""
            export XILINX_VITIS=""
            export LD_PRELOAD=""
            update_path "${xilinx_2019_install_dirs[@]}"
            ;;
        "2021")
            export XILINX_VIVADO=/opt/Xilinx/Vivado/2021.2
            export XILINX_HLS=/opt/Xilinx/Vitis_HLS/2021.2
            export XILINX_VITIS=/opt/Xilinx/Vitis/2021.2
            export LD_PRELOAD=""
            update_path "${xilinx_2021_install_dirs[@]}"
            ;;
        "2023")
            export XILINX_VIVADO=/opt/Xilinx/Vivado/2023.2
            export XILINX_HLS=/opt/Xilinx/Vitis_HLS/2023.2
            export XILINX_VITIS=/opt/Xilinx/Vitis/2023.2
            export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6
            update_path "${xilinx_2023_install_dirs[@]}"
            ;;
        "2024")
            export XILINX_VIVADO=/opt/Xilinx/Vivado/2024.2
            export XILINX_HLS=/opt/Xilinx/Vitis/2024.2
            export XILINX_VITIS=/opt/Xilinx/Vitis/2024.2
            export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6
            update_path "${xilinx_2024_install_dirs[@]}" 
            update_py_path "/opt/Xilinx/Vitis/2024.2/vfs/python"
            ;;
        *)
            echo "Invalid option. Try source-vivado -h"
            return 1
        ;;
    esac
}

