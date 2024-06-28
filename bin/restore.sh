#!/bin/bash

restore_dir() {
    cd $1
    echo "Restoring $1"
    ./bin/restore_config.sh
    cd ..
}

if [[ $1 == "" ]]; then
    for dir in ./* ; do
        if [ "$dir" != "./bin" ] && [ -d "$dir" ] && [ -f $dir/bin/restore_config.sh ]; then
            restore_dir $dir
        fi
    done
else
    restore_dir ./$1
fi
