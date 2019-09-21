#!/bin/bash
# Usage: EEG_Analysis_Auto.sh [OPTION]
# Example: EEG_Analysis_Auto.sh -ini /path/to/file -manager /path/to/exe -data /
# path/to/data -type extension
#
##
## xml, manager, and data arguments are mandatory. 
## type defaults to xltek (stc) 
## --xml            Pick the xml to do the analysis or conversion with; all files will use the same one.
## --manager        Path to the manager executable to be used for executing the xml and desired options.
## --data           Path to where the data is located. Parent folder is fine, will search recursively.
## --type           The type of data; extension of the type you want. (stc, edf, e, pnt, ref, lat, clampd)
## --include          A search pattern (regex allowed) or comma separated list of search patterns to include only specific files within a larger data directory.
## --exclude        A search pattern (regex allowed) to exclude specific files in a directory.
## --subseg         Provide a file that on each line has a file name or search pattern and a pair of start and length times for Manager to use when subsegmenting. Separate each item with comma.
## --traces         Output traces (OFileWriter). Give a list of comma separated strings of the traces you want to output, either a literal string or a file. 
## --analyze               Indicates to run analysis (OEventWriter). This is the default.
## --convert               Convert the file (OEDFWriter). Will add a consumer to write an edf file. This should rarely be used with analysis or --traces.
##

subsegs=()
dataTYPE=stc
eegEXTs=(stc edf e pnt ref lay clampd)
eegImporters=(XLTFile EDFFile EFile ONKTFile GrassFile OPersystFile OClampData)
consumerList=(OFileWriter OEDFWriter OEventWriter)
suffixList=(Output Convert Detections)
consumers=()
exclude=""
include=""

helpcomments () {
    sed -n "/##/{ s/##/ /p; }" "$0"
}

usage () {
    sed -n "/# [Uu]sage:/{N; s/# //gp; }" "$0"
}

isMember () {
  # First arg is array, second is value you want to check for in array.
  # Pass "exit" as third arg if you want it to exit on failure.
  declare -a arr=("${!1}")
  local memb="$2"
  local term="no"
  [[ $# -gt 2 ]] && term="$3"
  [[ ${#arr[@]} -eq 0 ]] && (echo "0"; return 1) 
  local found=0
  for j in ${arr[@]}; do
      if [[ "$j" == "$memb" ]]; then
          found=1
          printf "%s" "$found"
          return 0
      fi
  done
  if [[ $found -eq 0 ]] && [[ "$term" == "exit" ]]; then
      term 1 
  fi
  printf "%s" "$found"
}

pathExists () {
  # just one arg, a directory to check existence of.
  local dir="$1"
  if [ ! -d "$dir" ]; then
      printf "The data directory did not exist: %s\nexiting\n" "$dir"
      exit 1
  fi
  printf "Data path exists: %s\n" "$dir"
}

fileExists () {
  # one arg, file to check for existence of.
  local file="$1"
  if [ ! -e "$file" ]; then
      printf "The file did not exist: %s\n" "$file"
      exit 1
  fi
  printf "File exists: %s\n" "$file"
}

winPath () {
  # make sure the path will be agreeable to windows Manager.exe.
  printf "%s" "$(cygpath -m -a "$1")"
}

formatincexc () {
  # function to format the input to the include or --exclude options.
  # for the include, the second argument must be the file ending.
  append=""
  [[ $# -gt 1 ]] && append=".*$2"
  formatted="$(printf "%s" "$1" | sed -r "s/[,;: ]+/,/g; s/,$//")"
  reformat="(.*$(sed -r "s/,/${append}|.*/g" <<<"$formatted")${append})"
  printf "%s" "$reformat"
}

formatTraces () {
   # Take values separateed by comma or other dividers and 
   # format for use by Manager ini (single comma, no spaces, no trailing comma)
   printf "%b" "$(printf "%s" "$1" | sed -r "s/[,;:\. ]+/,/g; $ s/,$//")"
}

while [[ $# -gt 0 ]]; do
    key="$1"
    case "$key" in
    --xml)
    algXML="$2"
    algXML="$(winPath "$algXML")"
    fileExists "$algXML"
    shift
    ;;
    --analyze)
    analyze=true
    consumers+=("OEventWriter")
    ;;
    --convert)
    consumers+=("OEDFWriter")
    ;;
    --manager)
    managerEXE="$2"
    managerEXE="$(winPath "$managerEXE")"
    fileExists "$managerEXE"
    shift
    ;;
    --data)
    dataPATH="$2"
    dataPATH="$(winPath "$dataPATH")"
    pathExists "$dataPATH"
    shift
    ;;
    --type)
    dataTYPE="$2"
    isMember eegEXTs[@] "$dataTYPE" "exit"
    shift
    ;;
    --traces)
    traces="$2" 
    if [ -s "$traces" ]; then
        traces=$(<"$traces") 
    fi
    traces="$(formatTraces "$traces")"
    consumers+=("OFileWriter")
    shift
    ;;
    --subseg)
    subseg="$2"
    if [ -s "$traces" ]; then
        subseg=$(<"$traces") 
    fi
    ;;
    --include)
    include="$2"
    include="$(formatincexc "$include" "$dataTYPE")"
    printf "include: %s\n" "$include"
    shift
    ;;
    --exclude)
    exclude="$2"
    exclude="$(formatincexc "$exclude")"
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
    printf "Invalid option -- %s\n" "$key"
    printf "Try 'EEG_Analysis_Auto.sh --help' for details on use\n"
    exit
    ;;
    *)
    printf "This program takes no positional args\n"
    ;;
    esac

    shift
done

# see if all required information to run the program is present.
haveRequired () {
  if [[ ! -z ${algXML} && ! -z ${managerEXE} && ! -z ${dataPATH} ]]; then
      printf %s"Have all required information\n"
  else
      printf %s"Program requires valid options for --xml, --manager, and --data to run. Exiting.\n"
  fi
}

badcombo () {
  local edf=$(isMember consumers[@] "OEDFWriter") 
  local event=$(isMember consumers[@] "OEventWriter") 
  if [[ $edf -eq 1 && $event -eq 1 ]]; then
      printf %s"Using the converter and analyzer at the same time not allowed, exiting\n"
      exit
  fi
  
} 

haveRequired
badcombo
[[ "$include" == "" ]] && include=".*$dataTYPE"


# use this to get the index of an array based on a value.
getIndex () {
  # Take a value/element and an array and determine the 
  # index of that value within the array.
  val="$1"
  declare -a arr=("${!2}")
  for i in "${!arr[@]}"; do
   if [[ "${arr[$i]}" = "${val}" ]]; then
       echo "${i}";
       break
   fi
  done
}

writeINI () {
  local sourcePath="$1"
  local sinkPath="$2"
  local iniName="$3" 
  local noext="$4"
  local sinkNum=""
  if [[ ${#consumers[@]} -gt 1 ]]; then
      sinkNum=1
  fi
  # print out the [General] section
  printf "[General]\r\nSource = %s\r\nSink = \"%s\"\r\nXML = %s\r\n" "$importer" "$(echo "${consumers[@]}" | sed "s/ /,/g")" "$algXML" > "$iniName"
  # print out the [Source] section
  printf "[Source]\r\nPath = %s\r\nZeroFillGaps = True\r\n" "$sourcePath" >> "$iniName"
  # print out the [Sink] section
  for sink in "${consumers[@]}"; do
      case "$sink" in
      OEventWriter)
      printf "[Sink%s]\r\nPath = %s\r\n" "$sinkNum" "$sinkPath" >> "$iniName"
      ;;
      OFileWriter)
      printf "[Sink%s]\r\nTraces = \"%s\"\r\nPath = %s\r\nOneFile = False\r\n" "$sinkNum" "$traces" "${sinkPath}/Output.txt" >> "$iniName"
      ;;
      OEDFWriter)
      printf "[Sink%s]\r\nPath = %s/%s\r\n" "$sinkNum" "$sinkPath" "${noext}.edf">> "$iniName"
      ;;
      esac
      sinkNum=$((($sinkNum+1)))
  done
}

#subsegcreate () {
# See if there are subsegment requests, and if so make a statement for each one for this file in an a global array to be used.

#}

writeToBat () {
  INI="$1"
  BAT="$2"
  LOG="$3"
  printf "\"%s\" --progress \"%s\" >>\"%s\" 2>>&1\r\n" "$managerEXE" "$INI" "$LOG" >> "$BAT"
  printf "echo.>> \"%s\"\r\n\r\n" "$LOG" >> "$BAT"
}

determinename () {
  PATH="$1"
  local filename="${filepath##*/}"
  local withoutname="${filepath%/*}"
  local dirname="${withoutname##*/}"
  local noext="${filename%.*}"
  local usename="${noext}"
  if [[ ${#noext} -lt 15 ]]; then
    local usename="${dirname}_${noext}"
  fi
  printf "%s" "$usename"
}

processFiles () {
  local initial="$1"
  local ext="${initial##*.}"
  local typeBat="${batLOC}${suffix}_${ext}.bat"
  local typeLog="${logLOC}${suffix}_${ext}_log.txt"
  echo "" > "$typeBat"

  while (( $# )); do
    local filepath="$(cygpath -m "$1")" 
    printf "Current file: %s\n" "$filepath"
    local filename="${filepath##*/}"
    local usename="$(determinename "$filepath")"
    # local noext="${filename%.*}"
    local fileRslt="${rsltLOC}${usename}"
    mkdir -p "$fileRslt" 
    local fileIni="${iniLOC}${usename}_${suffix}.ini"
    if [[ $analyze -ne "true" ]]; then
      local fileRslt="${fileRslt}${usename}.edf"
    fi
    writeINI "$filepath" "$fileRslt" "$fileIni" "$usename" 
    [[ ${#subseg} -gt 1 ]] && subsegs="$(subsegcreate "$INI")"
    writeToBat "$fileIni" "$typeBat" "$typeLog" 
    subsegs=()
    shift
  done

}

findFiles () {
  IFSBACK=$IFS
  IFS=$'\n'
  processFiles $(find "$dataPATH" -regextype posix-extended -type d -regex "(.*EEG_Results|.*Analysis_Results)" -prune -o -type f -regex "$exclude" -prune -o -type f -regex "$1" -print) 
  IFS=$IFSBACK
}

iniLOC="$dataPATH/Manager_Code/inis/" 
xmlLOC="$dataPATH/Manager_Code/xmls/"
batLOC="$dataPATH/Manager_Code/bats/"
logLOC="$dataPATH/Manager_Code/logs/"
rsltLOC="$dataPATH/EEG_Results/"

mkdir -p "$logLOC" "$iniLOC"  "$xmlLOC"  "$batLOC"  "$rsltLOC"

suffix=()
for consumer in "${consumers[@]}"; do
  suffix+=(${suffixList[$(getIndex "$consumer" consumerList[@])]})
done
printf "Suffix array: %s\n" "${suffix[@]}"
suffix="$(echo "${suffix[@]}" | sed "s/ /_/g")"

for type in ${dataTYPE[@]}; do
  importer=${eegImporters[$(getIndex "$type" eegEXTs[@])]}
  printf "Type: %s\n" "$type"
  findFiles "$include"
done

