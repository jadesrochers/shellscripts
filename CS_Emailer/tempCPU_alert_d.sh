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
  printf "Shutting down CPU Temperature Alert Daemon on Date: %s\n\n" $(date --rfc-3339=seconds  | sed -e 's/ /_/g') >> $curLog
  kill -SIGINT $(jobs -p)
  exit 0
}

trap cleanup SIGHUP SIGINT SIGTERM SIGQUIT

log_dir="$(diskPath)"
log_err="${log_dir}/OIEresults/sysMonitor_alt.txt"

curLog="$(get_current_clampd)"
if [[ -z "$curLog" ]]; then curLog="$log_err"; fi
printf "Starting CPU Temperature Alert Daemon on Date: %s\n\n" $(date --rfc-3339=seconds  | sed -e 's/ /_/g') >> $curLog

lastDetect=50
optimaAddressOnly

while true; do 
  
  # get the current clampd log file name so I can write generic output there.
  curLog="$(get_current_clampd)"
  if [[ -z "$curLog" ]]; then curLog="$log_err"; touch -m "$curLog"; fi
  
  # Check if the clinical sites want the temp alert sent to them
  tempalerts=$(query_clamp_settings_byname "CPU Temp Alerts Enabled")
  if [[ $tempalerts -eq 0 || -z "$tempalerts" ]]; then tempalerts=false; else tempalerts=true; fi
  # Use the alert condition to select the correct emails
  if [[ $tempalerts == false ]]; then optimaAddressOnly; else get_smtpini_Addresses; fi
  
  # get the temperature from the /sys file system. Trim decimal portion.
  curtemp=$(cat /sys/bus/platform/devices/temp_sensor/celsius)
  curtemp=${curtemp%.*}
  if [[ $curtemp -eq 0 || -z "$curtemp" ]]; then curtemp=55; fi
  
  # logging to clampd log file
  if [[ -e $curLog ]]; then
    # printf "\nDate and Time: %s,  CPU Temp: %s \n" $(date --rfc-3339=seconds  | sed -e 's/ /_/g') $curtemp >> $curLog
    printf "CPU Temp: %s \n" $curtemp >> $curLog
  fi

  if [[ $curtemp -gt $(($lastDetect+30)) && $curtemp -gt 90 && $curtemp -le 119 ]]; then
    composeContent "$(printf "CereScope Notice - Screen Shutdown (Internal Temperature Reached %s C) on %s %s" $curtemp $(get_eth0ip) $(get_wlan0ip))" "$(printf "The screen of the device may have shutdown due to exceeding temperature limits")"
    lastDetect=$curtemp
	sendMessage $emails
  elif [[  $curtemp -ge $(($lastDetect+10)) && $curtemp -gt 119 ]]; then
    composeContent "$(printf "CereScope Notice - CPU Shutdown Possible (Internal Temperature Reached %s C) on %s %s" $curtemp $(get_eth0ip) $(get_wlan0ip))" "$(printf "The device processor is at risk of shutting down due to temperature limits.\n If this occurs, the device will turn off completely.")"
    lastDetect=$curtemp
	sendMessage $emails
  elif [[  $curtemp -lt $(($lastDetect-45)) && $curtemp -le 50 ]]; then
    lastDetect=$curtemp
  fi

  # wait between temp checks
  sleep 120s &
  wait
done


exit
