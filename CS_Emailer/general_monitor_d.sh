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
    nice -n 1 $me_DIR/$me_FILE session_refork "$tty" "$@" </dev/null >/dev/null 2>/dev/null &
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

########## COMPLETELY DETACHED (Third call) now a shell daeon;
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
  printf "Shutting down General Monitor Daemon on Date: %s\n\n" $(date --rfc-3339=seconds  | sed -e 's/ /_/g') >> $curLog
  kill -SIGINT $(jobs -p)
  exit 0
}

trap cleanup SIGHUP SIGINT SIGTERM SIGQUIT

log_dir="$(diskPath)"
log_err="${log_dir}/OIEresults/sysMonitor_alt.txt"

curLog="$(get_current_clampd)"
if [[ -z "$curLog" ]]; then curLog="$log_err"; fi
printf "Starting General Monitor Daemon on Date: %s\n\n" $(date --rfc-3339=seconds  | sed -e 's/ /_/g') >> $curLog

add_all_content () {
  local ip1=$(get_wlan0ip)
  local ip2=$(get_eth0ip)
  composeContent "$(printf "General CereScope Status Update on %s %s\n " $ip2 $ip1)"
  
  addHeader "Hardware Information (SD card, Batt, Temp):"
  addProcContentStorage
  addProcBattChg
  addContentCPUTemp
  
  addHeader "Process Information and Status:"
  addProcessInfo
  
  addHeader "Checking Analysis Status:"
  checkForBehind
  checkForEvents
  checkAnalysisLag
  checkAnalysisProtocol
  addContentResourceUse
  
  addHeader "Network Interface Information:"
  addContentIPMAC
}

lastDetect=-999
optimaAddressOnly

while true; do 
  
  # get the hour of the current time without padding zeros and trimming all white space.
  curHour=$(echo $(date -u +"%k") | tr -d '[[:space:]]')

  curLog="$(get_current_clampd)"
  # If enough time has passed and current time is a designated hour,
  # send out information about the system and write it to a log file.
  nowTime=$(date +%s)
  if [[ $(($nowTime - $lastDetect)) -gt 3601 ]]; then
    case $curHour in
      0|4|8|12|16|20)
	  # get the current clampd log file name so I can write output there in case email fails.
      curLog="$(get_current_clampd)"
      if [[ -z "$curLog" ]]; then curLog="$log_err"; fi
	  # send the email and write to the log
	  add_all_content
	  sendMessage $emails
	  lastDetect=$nowTime
	  # printf "\n\nStatus Update: %b\n\n" "$content" >> "$curLog"
	  ;;
    esac
  fi

  if [[ -e $curLog ]]; then
      printf "Current Analysis lag: %s\n" "$(get_behind_time)" >> "$curLog"
  fi

  # wait between doing checks
  sleep 120s &
  wait
done


exit
