#!/bin/bash
# Functions for sending email from bash shell
# providing openssl is available.

# database functions for use here
source /usr/share/IdentEvent/ShellScripts/sqlite_functions.sh
source /usr/share/IdentEvent/ShellScripts/monitor_functions.sh
source /usr/share/IdentEvent/ShellScripts/storage_device_fcns.sh
source /usr/share/IdentEvent/ShellScripts/battery_functions.sh

host_name=$(hostname)
# get email addresses from a file, with the default being the smtp file
get_smtpini_Addresses () {
if [[ $# -eq 0 ]]; then
  smtp_ini="$(diskPath)/smtp.ini"
else
  smtp_ini="$1"
fi

if [[ -e "$smtp_ini" ]]; then
   emails=$(sed -n -r 's/(Recipient[ ="'\'']+)(([[:alnum:]@&+-_{}#%!~\.\*\^]+([[:space:],]+))+)/\2/p' $smtp_ini)
   emails=$(sed 's/[;,"'\''[:space:]]/ /g' <<< "$emails")
else
   emails="identevent@gmail.com";
fi
}

optimaAddressOnly () {
  emails="identevent@gmail.com";
}

# This just sends the hostname in addition to the provided content.
sendMessage () {
if [[ $# -gt 0 ]]; then
local email_addrs
  while (( "$#" )); do
    email_addrs="$email_addrs <$1>"
  shift
  done
fi 

# Send the message, ignore the output.
(printf %"sHELO relay@tdt.com\n";
sleep 0.25;
printf %"sAUTH PLAIN AHJlbGF5QHRkdC5jb20AV0VGZ2h5NTY=\n";
sleep 1;
printf %"sMAIL FROM: <relay@tdt.com>\n";
sleep 0.25;
printf "RCPT TO:  %s\n" $email_addrs;
sleep 0.25;
printf %"sDATA\n";
sleep 0.25;
printf %"sFrom: 'Optima Team'<relay@tdt.com>\n";
sleep 0.25;
printf "To: %s\n" $email_addrs;
sleep 0.25;
printf "%b\n" "$subject";
sleep 0.25;
printf %"sContent-Type: text/html; charset=UTF-8\n";
sleep 0.25;
printf "%b" "$content"; 
sleep 1;
printf %"sQUIT\n") | openssl s_client -connect secure.emailsrvr.com:465 -crlf -ign_eof &>/dev/null
}

# first arument passed will be subject, all remainder will be used as content
# each on their own line
composeContent () {
  if (( "$#" )); then 
  clearContent
  subject="Subject: $1"
  shift
  fi

  while (( "$#" )); do
  content="<br>${content}$1<br> "
  shift
  done
  
  local uptime="$(parse_uptime)"
  content="<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">\
  <html><body>${content} <br><div class=locate></div><div style=\"text-decoration: underline;\"><b>System Information:</b>\
  </div><br>File system version: 0.9.27<br>hostname: \"$host_name\"<br>"
  content="${content}${uptime}<br>"
  content="${content}Date: $(date)<br></body></html>"
  content="${content}\r\n.\n\r"
}

clearContent ()  {
  unset content subject
}


addHeader () {
  local Heading="<div style=\"text-decoration: underline;\"><b>$1</b></div>"
  insertHeading "${Heading}"
}

# Network interface IP and MAC numbers
addContentIPMAC () {
  local wlan0info="$(ifconfig wlan0 2>/dev/null | grep -Ei '(hwaddr|inet)' | sed -r '1,2s/(wlan0 ).*[[:space:]](([[:xdigit:]]{2}:){5}[[:xdigit:]]{2})/\1\2/;1,2s/.*(addr:)(([0-9]{1,3}\.?){4}).*/\2/')";
  local eth0info="$(ifconfig eth0 2>/dev/null | grep -Ei '(hwaddr|inet)' | sed -r '1,2s/(eth0 ).*[[:space:]](([[:xdigit:]]{2}:){5}[[:xdigit:]]{2})/\1\2/;1,2s/.*(addr:)(([0-9]{1,3}\.?){4}).*/\2/')";
  insertContent "${wlan0info}" "${eth0info}"
}

# Recording state
addContentRecState () {
  local recstate=$(query_clamp_status_byname "Recording State";)
  local szdset=$(query_clamp_settings_byname "Detect Seizures";)
  local status=$(interpret_recording_status $recstate)

  if [[ szdset -eq 1 ]]; then szdset="On"; else szdset="Off"; fi
  insertContent "Recording State: ${status}" "Sz Detection Setting: ${szdset}" "Protocol Selected: ${szdproto}"
}

# Detection Protocol
checkAnalysisProtocol () {
  local szdproto=$(query_clamp_settings_byname "Sz Detection Protocol";)

  insertContent "Protocol Selected: ${szdproto}"
}


# Process info on Manager, ClampRun, ChunkWriter. A way to get recording state from system.
addProcessInfo () {
  local topInfo="$(topInfo_OptimaTDTProgs)"
  insertHeading "${topInfo}"
}

checkForBehind () {
  local countBehind="$(grep -E --regexp '^Fell Behind!!' "$(get_current_clampd)" | wc -l)"
  insertContent "Fell behind count: ${countBehind}"
}

checkForEvents () {
  local countEvents="$(grep -i "Event detected" "$(get_current_clampd)" | wc -l)"
  insertContent "Events detected count: ${countEvents}"
}

checkAnalysisLag () {
  local lagtime="$(get_behind_time)"
  insertContent "Current Analysis lag: ${lagtime}"
}

# Battery fill and charge
addContentBattChg () {
  local batfill=$(query_clamp_status_byname_nozero "Battery Charge";)
  local batcharge=$(query_clamp_status_byname "Battery Charging";)
  local batcharge=$(if [[ batcharge -eq 0 ]]; then echo "False"; else echo "True"; fi)
  insertContent "Battery Charging: ${batcharge}" "Battery fill: ${batfill}%"
}

# Battery fill and charge derived from files in /proc
addProcBattChg () {
  local batfill=$(battery_percent)
  local batcharging=$(isbatt_charging)
  insertContent "Is battery charging: ${batcharging}" "Battery fill percent: ${batfill}%"
}

# Temperature of CPU value
addContentResourceUse () {
  local cpuusage="<table style=\"width:40%;\"><tr><th colspan=\"4\">Cpu Usage</th></tr><tr>$(top -b -n 1 | awk '$1 ~ /^[Cc]pu\(s\):/ { \
  printf "<td>%s</td> <td>%s</td> <td>%s</td> <td>%s</td>", $2, $3, $4, $5}')</tr></table>"
  local memusage="<table style=\"width:40%;\"><tr><th colspan=\"2\">Memory Usage</th></tr><tr>$(top -b -n 1 | awk '$1 ~ /^[Mm]em:/ { \
  printf "<td>%s %s</td> <td>%s %s</td>", $2, $3, $4, $5}')</tr></table>"
  insertContent "${cpuusage}" "${memusage}"
}

# Temperature of CPU value
addContentCPUTemp () {
  local cputemp="$(cat /sys/bus/platform/devices/temp_sensor/celsius)"
  insertContent "Cpu Temperature:${cputemp}"
}


# Uptime output to see how long system has been on
addContentUptime () {
  local uptime_alt="$(parse_uptime)"
  local uptime_val=$(echo $(uptime) | sed -r -n 's/[0-9:[:space:]]+(up.*,)[[:space:]0-9]+user,(.*)/\1\2/p')
  insertContent "${uptime_alt}"
}

# Status of SD card
addContentStorage () {
  local storagePres=$(query_clamp_status_byname "Storage Present";)
  local storageFill=$(query_clamp_status_byname "Storage Fill";)
  insertContent "SD card percent full: ${storageFill}%" "SD card present: $storagePres"
}

# Status of SD card; get information from file system instead of our database
addProcContentStorage () {
  local storagePres="$(diskExists)"
  local storageFill="$(diskUsed)"
  local storageSize="$(diskSize)"
  insertContent "SD card percent full: ${storageFill}%" "SD Card Size: ${storageSize} MB" "SD card present: $storagePres"
}

addContentShunts () {
  local shuntChan=$(query_clamp_settings_byname "Disabled Channels";)
  insertContent "Shunted Channels: ${shuntChan}"
}

addContentAutos () {
  local autolock=$(query_clamp_settings_byname "AutolockSecs";)
  local autosleep=$(query_clamp_settings_byname "AutosleepMins";)
  insertContent "Autolock setting: ${autolock}" "Autosleep setting: ${autosleep}"
}

addContentExeStatus () {
  local exes=$(ps aux | grep -Ei "[^/]{1}([c]lamprun|[c]hunkwriter.*output|[a]mploader)" | awk '{ print $2 }')
  local programStat="<table style=\"width:45%;\"><tr><th>Process</th><th>Status</th><th>PID</th></tr>"
  for j in $exes; do
   local currComm="$(command_status $j)"
   programStat="${programStat}${currComm}"
  done
  insertHeading "${programStat}</table>"
}

# add content to email body. Each argument will be put on its own line in 
# the footer
insertContent () {
  content=${content/"<div class=locate>"/"<div class=locate>"}
  while (( "$#" )); do
    content=${content/"<div class=locate>"/"$1<br><div class=locate>"}
    shift
  done
  # the seemingly un-needed \n is so that the lines do not get too long.
  # Otherwise openssl will insert its own arbitrary line break.
  content=${content/"<div class=locate>"/"\n<br><div class=locate>"}
}

# add content to email body.
# For headings I do only a single newline afterwards
insertHeading () {
  content=${content/"<div class=locate>"/"<div class=locate>"}
  while (( "$#" )); do
    content=${content/"<div class=locate>"/"$1<br><div class=locate>"}
    shift
  done
}
