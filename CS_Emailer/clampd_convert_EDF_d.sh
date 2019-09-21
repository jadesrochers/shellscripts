#!/bin/bash
# This runs in the form of a daemon. 
# The first part is the same in all shellscript daemons to set up the daemon.
# Then the rest will run as the program content.

me_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
me_FILE=$(basename $0)

########## NEW SESSION CHILD (Second call) HERE;
# This time this script is running in a new session as a child of that session.
# cd to root and umask reset done to meet "true" daemon conditions.
# fork again (&) to make it so the process is not a session leader.
# The file descriptors are changed to null so none are linked to the original locations.
if [ "$1" = "child" ] ; then
    cd /
    shift; tty="$1"; shift
    umask 0
    nice -n 2 $me_DIR/$me_FILE session_refork "$tty" "$@" </dev/null >/dev/null 2>/dev/null &
    exit 0
fi

########## INITIAL CALL GOES HERE; 
# use setsid and "&" to call the process again but give it its
# own session and then make it a child of that session. 
# "child" is dummy argument for this script so
# it can be determined when the first self call has been done.
if [ "$1" != "session_refork" ] ; then
    tty=$(tty)
    setsid $me_DIR/$me_FILE child "$tty" "$@" &
    exit 0
fi

########## COMPLETELY DETACHED (Third call) now a shell daemon;
# The script is not running in its own session but not as the session leader.
# It is running from root or another relevant directory so that it does not keep calling directory active.
# The umask is set to zero.
# the descriptors can now be re-assigned for the purpose of the current program.
# The looop determines the actions of the program.

exec >/tmp/outfile
exec 2>/tmp/errfile
exec 0</dev/null

shift; tty="$1"; shift

##############  Body of code to be run
source /usr/share/IdentEvent/ShellScripts/email_functions.sh

cleanup () {
  printf "Shutting down Clampd to EDF Converting Daemon on Date: %s\n\n" $(date --rfc-3339=seconds  | sed -e 's/ /_/g') >> $curLog
  kill -SIGINT $(jobs -p)
  exit 0
}

trap cleanup SIGHUP SIGINT SIGTERM SIGQUIT

basexml="/usr/share/IdentEvent/XML/ClampToEDF_400.xml"
printf "Starting Clampd Converter Daemon on Date: %s\n\n" $(date --rfc-3339=seconds  | sed -e 's/ /_/g') >> $curLog

refresh_filelocs () {
  diskpath="$(diskPath)"
  fileloc="${diskpath}/OIEresults/"
  log_dir="$diskpath"
  log_err="${log_dir}/OIEresults/sysMonitor_alt.txt"
}

refresh_log () {
  # update the log for this daemon to match the newest clampd or use independent file.
  refresh_filelocs
  curLog="$(get_current_clampd)"
  if [[ -z "$curLog" ]]; then curLog="$log_err"; fi
}

# check and see if recording, wait if so.
isRecording () {
  local recstate=$(query_clamp_status_byname "Recording State";)
  local recbool
  if [[ $recstate == "i" ]]; then recbool="false"; else recbool="true"; fi
  printf "%s" "$recbool"
}


get_file_age () {
  # will determine age of file in terms of last modified compared to current.
  # pass it the name of the file you want to check.
  local file="$1"
  local filetime=$(echo "$entry" | awk '{printf "%s\n", $1}')
  local curtime="$(date +"%s")"
  local fileage=$(($curtime - $filetime))
  printf "%d" "$fileage"
}

diskandfile_exist () {
  # determine if the SD card is inserted, and if there are any files to 
  # process. If yes, return true, if not, false and log the result.
  rslt="false"
  refresh_log
  local diskbool=$(diskExists)

  while (( "$#" )); do
    shift
    local file="$1"
    local fileslengt=${#file}
    if [[ "$diskbool" == "true" && $fileslengt -gt 15 ]]; then
      rslt="true"
    fi
    shift
  done
  printf "%s" "$rslt"  
    
}

clampd_date () {
  # Take a clampd file and get the converted, human readable date.
  local sourcepath="$1"
  local filename="${sourcepath##*/}"
  local clamptime="$(sed -r "s/rec_//g; s/.clampd//g" <<<"$filename")"
  local humantime="$(date +"%Y_%b_%d-%H%M" -d @$clamptime)"
  printf "%s" "$humantime"
}

clampd_edf () {
  # convert the clampd file name into and edf name
  local humantime="$1"
  local edffile="${fileloc}rec_${humantime}.edf"
  printf "%s" "$edffile"
}

was_converted () {
  # check and see if the file was already converted, give path to clamp file.
  rslt="false"
  local sourcepath="$1"
  local edfpath="$(clampd_edf $(clampd_date "$sourcepath"))"
  if [[ -e "$edfpath" ]]; then
    rslt="true"
  fi
  printf "%s" "$rslt"
}

space_check () {
  rslt="false"
  filesize="$(fileSize "$1")"
  diskfree="$(diskMBFree)"
  if [[ $diskfree -gt $filesize ]]; then
    printf "Conversion passed space check\n"
    rslt="true"
  fi
  printf "%s" "$rslt"
}

setup_convert () {
  local sourcepath="$1"
  local recstate="$(isRecording)"
  if [[ "$recstate" == "true" ]]; then
    printf %s"CereScope is still recording, exiting conversion\n" >> "$curLog"
    return
  fi
  local fileage=$(get_file_age "$sourcepath")
  if [[ $fileage -lt 301 ]]; then
    printf "File %s modified recently, exiting conversion\n" "$sourcepath" >> "$curLog"
    return
  fi
  local alreadyconvert="$(was_converted "$sourcepath")"
  if [[ "$alreadyconvert" == "true" ]]; then
    printf "File %s already converted, exiting conversion\n" "$sourcepath" >> "$curLog"
    return
  fi
  local enoughspace="$(space_check "$sourcepath")"
  if [[ "$enoughspace" == "false" ]]; then
    printf "Conversion of %s may fill disk, exiting conversion\n" "$sourcepath" >> "$curLog"
    return
  fi
  
  local lastmod="$2"
  local humantime="$(clampd_date "$sourcepath")"
  local ininame="${fileloc}convert_${humantime}.ini"
  local edffile="$(clampd_edf "$humantime")"
  
   # print out the [General] section
  printf "[General]\nSource = %s\nSink = %s\nXML = %s\n" "OClampData" "OEDFWriter" "$basexml" > "$ininame"
  # print out the [Source] section
  printf "[Source]\r\nPath = %s\r\nZeroFillGaps = True\r\n" "$sourcepath" >> "$ininame"
  # add in the [Sink] section
  printf "[Sink]\r\nPath = %s\n" "$edffile" >> "$ininame"
  run_convert "$sourcepath" "$ininame"
}

run_convert () {
  export LD_LIBRARY_PATH=/usr/local/lib
  local ini="$2"
  local sourcepath="$1"
  local humantime="$(clampd_date "$sourcepath")"
  local manager="/usr/local/bin/Manager"
  local config="--config=/usr/share/IdentEvent/config.ini"
  local filename="${sourcepath##*/}"
  local clamptime="$(sed -r "s/rec_//g; s/.clampd//g" <<<"$filename")"
  local logfile="${fileloc}convert_${clamptime}_${humantime}.log"
  local logcommand="--log-file=${fileloc}convert_${clamptime}.log"
  printf "\nCommand to be run:  %s %s %s %s %s %s\n\n" "$manager" "$config" "$logcommand" "$ini" "&>" "$logfile" >> $curLog
  # Having trouble getting the nice number to work, seems to lead 
  # to very slow conversion no matter the exact details.
  # nice -1 "$manager" "$config" "$logcommand" "$ini" &> "$logfile"
  ("$manager" "$config" "$logcommand" "$ini" &> "$logfile") &
  convertPID=$(ps -ef | grep -i "[m]anager.*[c]onvert" | awk '{printf "%s\n", $2}')
  local stopped="false"
  while [[  "$(ps -j $convertPID | sed -n '1 !p' | awk '{printf "%s\n", $1}')" -gt 0 ]];do
    local recstate="$(isRecording)"
    if [[ "$recstate" == "true" && "$stopped" == "false" ]]; then
      printf "Suspending conversion because recording started\n"  >> $curLog
      kill -STOP $convertPID
      stopped="true"
    elif [[ "$recstate" == "false" && "$stopped" == "true" ]]; then
      printf "Resuming conversion because recording done\n"  >> $curLog
      kill -CONT $convertPID
      stopped="false"
    elif [[ "$stopped" == "true" ]]; then
      printf "Conversion still suspended\n"  >> $curLog
      # :
    else
      printf "Convertsion running as PID %s\n" "$convertPID"  >> $curLog
      # :
    fi
    sleep 60s
  done
  printf "Done converting, PID %s should be complete\n" "$convertPID"  >> $curLog
}

# Go through all files and convert if criteria are met
convert_all () {
  diskbool=$(diskExists)
  allclampd="$(get_all_rec)"
  recordingsbool="$(diskandfile_exist $allclampd)"
  if [[ "$recordingsbool" == "false" ]]; then
    return
  fi    
  
  IFSback="$IFS"
  IFS=$'\n'
  for entry in $allclampd; do
    file=$(echo "$entry" | awk '{printf "%s\n", $2}')
    fileage=$(get_file_age "$file")
    setup_convert "$file" "$fileage"
  done
  IFS=$IFSback
  
}

refresh_log 
convert_all

while true; do 
  refresh_log   
  curfile="placeholder $(get_current_rec)"
  printf "Converter main loop; curfile is %s\n" "$curfile" >> $curLog
  recordingsbool="$(diskandfile_exist $curfile)"
  if [[ "$recordingsbool" == "false" ]]; then
      printf "Converter main loop; nothing to convert, waiting 250s\n" >> $curLog
  else 
      convert_all
  fi
  
  # wait between doing checks
  sleep 250s &
  wait
done
