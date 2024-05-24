A repo to back up my linux environment.

### Usage
`./bin/save.sh` copies config for all apps to the directories in the repo workspace
`./bin/restore.sh` overwrites running config files with files from the repo workspace
Both scripts accept one argument to save or restore a single app
Example: `./bin/save.sh vim` saves vim config only

### App directory format
To add a new app whose config you want to track, 
```
mkdir $app
mkdir $app/bin
touch $app/bin/save_config.sh
touch $app/bin/restor_config.sh
chmod +x $app/bin/*
```
where `save_config.sh` copies running app config files to . and `restore_config.sh` copies/overwites files from . to running app config locations 
