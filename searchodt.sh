#!/bin/bash
# Input to the command is the search term.
# Usage: searchodt [OPTION]... [PATTERN]...
# Example: searchodt -i -f "Linux"  UEFI Gpt
#
## -i                   case insensitive matching for both 
##                        the file name and contents.
## -l, --location       location to search for openoffice files;
##                        full system path.
## -f, --fname          specify a search pattern for the file name.
##                        this is a find search; regex is allowed by default.
##    --regextype       provide a regextype for the grep search
##                        of the odt file contents.
##                        default is --basic-regexp. Allowed options are:
##                        "--basic-regexp", "--perl-regexp" 
##                        and "--extended-regexp"
## -h, --help           get output on how to use searchodt
## -u, --usage          just the usage portion of the help with example.

ARGUMENTS=()
searchPath="/home/jad/Tutorial_Notes"
searchType="-regex"
nameSearch="/"
regexType="--basic-regexp"
grepopts="-q"

helpcomments () {
    sed -n "/##/{ s/##/ /p; }" $0
}

usage () {
    sed -n "/# [Uu]sage:/{N; s/# //gp; }" $0
}

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -i)
    INSENS=true
    searchType="-iregex"
    grepopts="${grepopts}i"
    ;;
    -l|--location)
    searchPath="$2"
    shift
    ;;
    -f|--fname)
    nameSearch="$2"
    shift
    ;;
    --regextype)
    regexType="$2"
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
    *)
    # arguments to search for in the file, multiple arguments allowed for an OR search 
    # printf "Adding to ARG: %s\n" "$key"
    ARGUMENTS[${#ARGUMENTS[@]}]="$key"
    ;;

esac
shift
done

debug_info () {
    printf "Argument INSENS: %s\n"  "$INSENS"
    printf "Argument -l: %s\n"  "$searchPath"
    printf "Argument -fname: %s\n"  "$nameSearch"
    printf "Argument --regextype: %s\n"  "$regexType"
    printf "Arguments: %s\n"  "${ARGUMENTS[@]}"
    printf "Name of this script: %s\n" "$(basename \"$0\")"
}

# function join_by { local IFS="$1"; shift; echo "$*"; }
# purpose is to join arguments to for a proper 'OR' regex.
join_by () {
    local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}";
}

remove_formatting () {
    local newcontent=$(sed "s/<[^>]*>/<>/g" <<<"$1") 
    local newcontent=$(sed "s/[<>]\{1,\}//g" <<<"$newcontent") 
    content="$newcontent"
}

if [ ${#ARGUMENTS} -gt 0 ]; then
    argRegex="\($(join_by "\\|" "${ARGUMENTS[@]}")\)"
fi

# looks through entire file system minus exclusions by default.
# Need to edit the exclusion list if undesired files are searched.
IFS_back=$IFS; IFS=$'\n'
for filepath in $(sudo find "$searchPath" -xdev -type f -regextype posix-extended "$searchType" ".*${nameSearch}.*\.odt$" -print | sort -fd ); do
    # printf "File path: %s\n" "$filepath"
    content=$(unzip -p "$filepath" content.xml)
    echo "$content" | grep "$regexType" "${grepopts}" "$argRegex"
    if [ $? -eq 0 ]; then
        printf "\nFile matching search parameters: %s\n" "$filepath"
    fi
done
IFS=$IFS_back
