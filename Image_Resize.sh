#!/bin/bash

# Usage: Image_Resize.sh [OPTIONS]
# Example: Image_Resize.sh --dir /path/to/files --size X (mb) --type jpg
#
## --type   The type of image file to look for. Required.
## --dir    Directory that contains the data. Required.
## --size   The size in Mb for the files, will use it as a maximum. Defaults to <1 Mb.

helpcomments () {
    sed -n "/#\{2\}/{ s/#\{2\}/ /p; }" $0
}

usage () {
    sed -n "/# [Uu]sage:/{N; s/# //gp; }" $0
}


while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    --type)
        filetype="$2"
    shift
    ;;
    --dir)
        dirpath="$2"
    shift
    ;;
    --size)
        filesize="$2"
    shift
    ;;
    -h|--help)
    usage
    helpcomments
    exit
    ;;
    -u|--usage)
    usage
    exit
    ;;
    -*)
    printf "Invalid option -- %s\n" "$key"        # unknown option
    printf "Try 'searchodt --help' for more information\n"
    exit
    ;;
esac
shift
done

find_dir () {
  if [[ ! -d "$dirpath" ]]; then 
    printf %s"Could not find directory, exiting\n"
    exit
  fi
}

check_for_files () {
  files="$(find "$dirpath" -type f -iregex ".*\.${filetype}"  -print -quit)"
  if [[ ! -n "$files" ]]; then
    printf %s"Could not find any files, exiting\n"
  fi
}

resize_files () {
  pushd "$dirpath" > /dev/null
  shopt -s nocaseglob
  for image in *${filetype}; do
    imagename="${image%.*}"
    convert "$image" -define jpeg:extent=850kb "${imagename}_rs.${filetype}"
  done 
  popd > /dev/null
}

find_dir
check_for_files
resize_files

