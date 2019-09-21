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
  printf "Shutting down Low Battery Alert Daemon on Date: %s\n\n" $(date --rfc-3339=seconds  | sed -e 's/ /_/g') >> $curLog
  kill -SIGINT $(jobs -p)
  exit 0
}

trap cleanup SIGHUP SIGINT SIGTERM SIGQUIT

startManager () {
	local writers=$(top -b -n 1 | awk '$12 ~/ChunkWriter/ && $9>5 && $10>5 {printf "Mem: %s CPU: %s\n",$10,$9}' | wc -l)	
	export LD_LIBRARY_PATH=/usr/local/lib

	# This double backgrouding detaches the program so this script keeps running. 
	if [[ $writers -gt 0 ]]; then
	((/usr/local/bin/Manager --log-file "${curLog}"  \
	--config=/usr/share/IdentEvent/config.ini /usr/share/IdentEvent/OClampImporter_OEventNotifier.ini \
	1>/var/log/Manager-out.log 2>/var/log/Manager-err.log &) &)
	printf "\nAttempting Manager restart after battery recharged to an acceptable level.\n\n" >> "$curLog"
	fi
manPid=$(pgrep Manager | wc -l)
if [[ $manPid -eq 1 ]]; then (exit 0); else (exit 1); fi
}

killManager () {
	loopCt=0
	while [[ $(pgrep Manager | wc -l) -gt 0 ]]; do
	local manPid=$(pgrep Manager)
	kill -15 $manPid &>/dev/null 
	sleep 5
	loopCt=$((loopCt+1))
	printf "\nAttempting Manager shut down because the battery fell too low.\n\n" >> "$curLog"
	if [[ $loopCt -gt 5 ]]; then kill -9 $manPid; fi
	done
manPid=$(pgrep Manager | wc -l)
if [[ $manPid -eq 0 ]]; then (exit 0); else (exit 1); fi
}

log_dir="$(diskPath)"
log_err="${log_dir}/OIEresults/sysMonitor_alt.txt"

curLog="$(get_current_clampd)"
if [[ -z "$curLog" ]]; then curLog="$log_err"; fi
printf "Starting Low Battery Alert Daemon on Date: %s\n\n" $(date --rfc-3339=seconds  | sed -e 's/ /_/g') >> $curLog

# will parse the file it is given or use default to get email addresses
optimaAddressOnly
lastDetect=90
lowDetect=90
chargeswitch=1

# Check the database for the charge status,
# then run this through some logic to determine when to send out a message
while true; do 

  # get the current clampd log file name so I can write generic output there.
  curLog="$(get_current_clampd)"
  if [[ -z "$curLog" ]]; then curLog="$log_err"; touch -m "$curLog"; fi
  
  # get the battery charge state and number from database
  # charging=$(query_clamp_status_byname "Battery Charging")
  charging=$(isbatt_charging)
  if [[ -z "$charging" ]]; then charging=false; fi
  
  charge=$(battery_percent)
  tryagain=1
  while [[ ("$charge" == "error" || -z "$charge") && tryagain -lt 10 ]]; do
    sleep 3s &
    wait
    charge=$(battery_percent)
    tryagain=tryagain+1
  done
  if [[ -z "$charge" ]]; then charge=9999; fi
  
  battalerts=$(query_clamp_settings_byname "Battery Alerts Enabled")
  if [[ $battalerts -eq 0 || -z "$battalerts" ]]; then battalerts=false; else battalerts=true; fi
  # Use the alert condition to select the correct emails
  if [[ $battalerts == false ]]; then optimaAddressOnly; else get_smtpini_Addresses; fi

  # logging to clampd log file
  if [[ -e $curLog ]]; then
    # printf "\nDate and Time: %s\n" $(date --rfc-3339=seconds  | sed -e 's/ /_/g') >> $curLog
    printf "Battery charging: %s, Charge percent: %d \n" "$charging" "$charge" >> $curLog
  fi

  # send an alert if the battery reaches a certain discharge point, or starts charging again.
  if [[ $charging == false ]] && ( [[ $charge -le $(($lastDetect-30)) && ($charge -le 60 && $charge -gt 20 ) ]] || [[ $charge -le $(($lastDetect-15)) && $charge -le 20 ]] ); then
    # printf %"sSending out a low battery Alert\n" >> $curLog
    composeContent "$(printf "CereScope Battery Notice (Down to %d%%) on %s %s" $charge $(get_eth0ip) $(get_wlan0ip))" "$(printf "The battery has fallen to %s%%" $charge)"
    lastDetect=$charge
    chargeswitch=0
    sendMessage $emails
  elif [[ $charge -gt $(($lastDetect+30)) && $chargeswitch -eq 0 && $charging == true ]]; then 
    composeContent "$(printf "CereScope Battery Notice (Recharging and at %d%%) on %s %s" $charge $(get_eth0ip) $(get_wlan0ip))" "$(printf "The battery is back up to %s%%" $charge)"
    chargeswitch=1
	lastDetect=$charge
    sendMessage $emails
  fi

  if [[ $charging == false ]] && [[ $charge -le $(($lowDetect-30)) && ($charge -le 9 ) ]]; then 
	lowDetect=$charge
	killManager & 
	wait
    if [[ $? -eq 0 ]]; then printf "Manager Shut Down at battery level: %s\n" $lowDetect >> $curLog; fi 
  elif [[  $charging == true ]] && [[ $charge -gt $(($lowDetect+50)) ]]; then 
	lowDetect=$charge
        startManager &
	wait
    if [[ $? -eq 0 ]]; then printf "Manager Restarted at battery level: %s\n" $lowDetect >> $curLog; fi 
  fi

  # wait between battery checks.
  sleep 120s &
  wait
done


exit
