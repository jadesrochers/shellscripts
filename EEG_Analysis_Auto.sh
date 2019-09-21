#!/bin/bash
# Usage: EEG_Analysis_Auto.sh [OPTION]
# Example: EEG_Analysis_Auto.sh -ini /path/to/file -manager /path/to/exe -data /
# path/to/data -type extension
#
##
## xml, manager, and data arguments are mandatory. 
## type defaults to xltek (stc) 
## --xml                 Pick the xml to do the analysis with;
##                          all files will use the same one.
## --manager             Path to the manager executable to be used 
##                          for this analysis
## --data                Path to where the data is located. Parent 
##                          folder is fine, will search recursively.
## --type                The type of data; extension of the type 
##                          you want. (stc, edf, e, pnt, ref, lat,  ##                          clampd)
## --traces              Give a list of comma separated strings of 
##                          the traces you want to output, either 
##                          a literal string or a file.
## -a                    Indicates to run analysis (OEventWriter).
##                          This is the default.
## -c                    Convert the file. Will add a consumer
##                          to write an edf file. This should rarely
##                          be used with analysis or --traces.
##

dataTYPE=stc
eegEXTs=(stc edf e pnt ref lay clampd)
eegImporters=(XLTFile EDFFile EFile ONKTFile GrassFile OPersystFile OClampData)
consumerList=(OFileWriter OEDFWriter OEventWriter)
suffixList=(Output Convert Detections)
consumers=()

helpcomments () {
    sed -n "/##/{ s/##/ /p; }" "$0"
}

usage () {
    sed -n "/# [Uu]sage:/{N; s/# //gp; }" "$0"
}

isMember () {
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
  local dir="$1"
  if [ ! -d "$dir" ]; then
      printf "The data directory did not exist: %s\nexiting\n" "$dir"
      exit 1
  fi
  printf "Data path exists: %s\n" "$dir"
}

fileExists () {
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

formatTraces () {
   printf "%b" "$(printf "%s" "$1" | sed -r "s/[,;:\. ]+/,/g; s/,$//;")"
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
    -a)
    analyze=true
    consumers+=("OEventWriter")
    ;;
    -c)
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
    printf "Try 'progname --help' for details on use\n"
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

writeFiles () {

  printf "[Sink%s]\nPath = %s" "$1" "${sinkPath}/Output.txt" >> "$iniName"
}

writeEDFs () {

  printf "[Sink%s]\nPath = %s" "$1" "$sinkPath" >> "$iniName"
}

writeEvents () {

  printf "[Sink%s]\nPath = %s" "$1" "$sinkPath" >> "$iniName"
}

writeINI () {
  local sourcePath="$1"
  local sinkPath="$2"
  local iniName="$3" 
  local noext="$4"
  local sinkNum=1
  # print out the [General] section
  printf "[General]\nSource = %s\nSink = %s\nXML = %s\n" "$importer" "$(echo "${consumers[@]}" | sed "s/ /,/g")" "$algXML" > "$iniName"
  # print out the [Source] section
  printf "[Source]\nPath = %s\nZeroFillGaps = TRUE\n" "$sourcePath" >> "$iniName"
  # print out the [Sink] section
  for sink in "${consumers[@]}"; do
      case "$sink" in
      OEventWriter)
      printf "[Sink%s]\nPath = %s" "$sinkNum" "$sinkPath" >> "$iniName"
      ;;
      OFileWriter)
      printf "[Sink%s]\nTraces = \"%s\"\nPath = %s\nOneFile = False\n" "$sinkNum" "$traces" "${sinkPath}/Output.txt" >> "$iniName"
      ;;
      OEDFWriter)
      printf "[Sink%s]\nPath = %s/%s\n" "$sinkNum" "$sinkPath" "${noext}.edf">> "$iniName"
      ;;
      esac
      sinkNum=$((($sinkNum+1)))
  done
}

writeToBat () {
  INI="$1"
  BAT="$2"
  LOG="$3"
  printf "\"%s\" --progress \"%s\" >>\"%s\" 2>>&1\n" "$managerEXE" "$INI" "$LOG" >> "$BAT"
  printf "echo.>> \"%s\"\n\n" "$LOG" >> "$BAT"
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
    local noext="${filename%.*}"
    local fileRslt="${rsltLOC}${noext}"
    mkdir -p "$fileRslt" 
    local fileIni="${iniLOC}${noext}_${suffix}.ini"
    if [[ $analyze -ne "true" ]]; then
      local fileRslt="${fileRslt}${noext}.edf"
    fi
    writeINI "$filepath" "$fileRslt" "$fileIni" "$noext" 
    writeToBat "$fileIni" "$typeBat" "$typeLog"
    shift
  done

}

findFiles () {
  IFSBACK=$IFS
  IFS=$'\n'
  processFiles $(find "$dataPATH" -type f -iname "*.$1") 
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
  findFiles "$type"
done

