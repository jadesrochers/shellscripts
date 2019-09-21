#! /bin/bash
# a script providing functions to backup files to dropbox
# The config file is at ~/etc


# If you want to add a file type, put it in here.
source /usr/local/etc/general_back.conf

# Takes all the args and turns them into a series of includes for rsync.
# Storing in an array allows passing the arguments as a variable
transform_toinclude () {
  unset filesbuild filesinclude
  while (( "$#" )); do
    filesinclude+=("--include" "*$1")
    shift
  done
}

# get the list of file types to search for
backup_filetype () {
  local filesearch=$(transform_tosearch "$@")
  printf "%s" "$filesearch"  
}
 
# Do the backup using dir to backup, destination, file patterns
backup_dirs () { 
    # $1 is the directory being backed up
    # $2 is the destination location to copy to
    # "${filesinclude[@]}" is the search pattern for files in the directory being backed up
    # printf "Args in use order: %s  %s  %s \n" "${filesinclude[@]}" "$1" "$2"
    rsync -au -m --delete "${filesinclude[@]}" --include "*/" --exclude "*" "$1" "$2" 
    find "$backup_loc" -type f -iname "*case conflict*" -exec rm {} \; &> /dev/null
}

# go through all the directories listed in the config to backup
# and run the backup with the paired destinations and and file types
run_backup () {
    local typesearch
    i=0
    backcount=${#directories[@]}
    while [[ i -lt $backcount ]]; do
      if [[ ! -d "${destinations[$i]}" ]]; then
	printf "Attempting to create: %s\n" "${destinations[$i]}"
        mkdir -p "${destinations[$i]}"
      fi
      transform_toinclude "${!filetypes[$i]}"
      backup_dirs "${directories[$i]}" "${destinations[$i]}" 
      i=$((i+1))
    done
}

