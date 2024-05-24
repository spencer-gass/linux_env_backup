#!/bin/bash

save_dir() {
    cd $1
    echo "Saving $1"
    ./bin/save_config.sh
    cd ..
}

if [[ $1 == "" ]]; then
    for dir in ./* ; do
        if [ "$dir" != "./bin" ] && [ -d "$dir" ]; then
            save_dir $dir
        fi
    done
else
    save_dir ./$1
fi
