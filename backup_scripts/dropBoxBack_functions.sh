#! /bin/bash
# a script providing functions to backup files to dropbox
# The config file is at ~/etc


# If you want to add a file type, put it in here.
source /home/jadesrochers/etc/dropBoxBack.conf

# clean up the arguments list so that it can look nice
# in the .conf file
neaten_conf () {
    # get rid of newlines
    local cleanprepare="$(tr '\n' ' ' <<<$1)"
    # then neaten spaces and commas
    local cleanvar="$(sed -r 's/[,[:space:]]+/ /g' <<<${cleanprepare})"
    printf "%s" "$cleanvar"
}

# take a variable with a list of items and turn it into
# a regular expression search for each of them 
transform_tosearch () {
  local cleanvar="$(neaten_conf "$1")"
  local varsearch=$(printf "(%s)" $(printf ".*\\%s$|" $cleanvar))
  varsearch=$(sed 's/(|/(/; s/|)/)/' <<< "$varsearch")
  printf "%s" "$varsearch"
}

# get the list of file types to search for
backup_filetype () {
  local filesearch=$(transform_tosearch "$1")
  printf "%s" "$filesearch"  
}

exclude_always () {
  local prunesearch=$(transform_tosearch "$1")
  printf "%s" "$prunesearch"  
}

backup_dirs () {
    local excluded typesearch backup_loc
    excluded="$(exclude_always "$exclude")"
    typesearch="$(backup_filetype "$filetypes")"
    backup_loc="$(neaten_conf "$destination")"
    while (( "$#" )); do
        find "$1" -xdev -regextype posix-extended -type d -regex "$excluded" -prune -o -type f -size -150k -regex "$typesearch" -print -exec cp -au {} "$backup_loc" \; &> /dev/null
        shift  
    done
    find "$backup_loc" -type f -iname "*case conflict*" -exec rm {} \;
}

run_backup () {
    backup_dirs $(neaten_conf "$directories")
}

