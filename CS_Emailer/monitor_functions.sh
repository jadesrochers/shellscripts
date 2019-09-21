#!/bin/bash
# Functions for monitoring process status and system information

# Get interface ip addresses
get_wlan0ip () {
  printf "%s" $(ifconfig wlan0 2>/dev/null | grep -Ei 'inet' | sed -r '1s/.*addr.(([0-9]{1,3}\.?){4}).*/\1/')
}

get_eth0ip () {
  printf "%s" $(ifconfig eth0 2>/dev/null | grep -Ei 'inet' | sed -r '1s/.*addr.(([0-9]{1,3}\.?){4}).*/\1/')
}

# get the most recent clampd log file
get_current_clampd () {
  find "$(diskPath)/OIEresults" -type f -iname "rec*.log*" -printf "%C@ %p\n" | sort | tail -n 1 | awk '{printf "%s\n", $2}'
}

# get the most recent clampd file path
get_current_rec () {
  find "$(diskPath)/OIEresults" -type f -iname "*.clampd*" -printf "%C@ %p\n" | sort | tail -n 1 | awk '{printf "%s\n", $2}'
}

# get all clampd file paths
get_all_rec () {
  find "$(diskPath)/OIEresults" -type f -iname "*.clampd*" -printf "%T@ %p\n"
}


get_behind_time () {
  local startDateTime="$(head -n 500 "$(get_current_clampd)" | grep -A 1 "Current tick: 0" | sed -n "2 s/.*at: //p")"
  local initializeTime="$(head -n 100 "$(get_current_clampd)" | grep "prepareToPull" | awk '{ printf "%s", $4 }')"

  local curOffandDate="$(tac "$(get_current_clampd)" | sed -rn "/^Epoch Processing start.*[0-2][0-9]:[0-6][0-9]:[0-6][0-9].[0-9]+/{N; /^Current tick: [0-9]+ .*[0-2][0-9]:[0-6][0-9]:[0-6][0-9]/{p; q;}}")"
  local currentDateTime="$(echo "$curOffandDate" | sed -n "1 s/.*at: //p")"
  local currentOffset="$(echo "$curOffandDate" | sed -n "2 p" | awk '{ printf "%s", $6 }')"
  local behindsec=$(python "/usr/share/IdentEvent/ShellScripts/behind_time.py" "$startDateTime" "$initializeTime" "$currentDateTime" "$currentOffset")
  # local behindsec=$(python "/root/behind_time.py" "$startDateTime" "$initializeTime" "$currentDateTime" "$currentOffset")
  printf "%s seconds\n" "$behindsec"
}

# when recording status is pulled from database need to interpret it
interpret_recording_status () {
  if [[ $1 == "r" ]]; then
    local status="Recording"
  elif [[ $1 == "s" || $1 == "i" ]]; then
    local status="Idle"
  else
    local status="$1"
  fi
  printf "%s" $status
}

# get the status on a process from /proc filesystem
awkProgramStatComm='
BEGIN {ORS=" "} 
{
if($1=="Name:"){
  name=sprintf("%s", $2)
}
else if($1=="State:"){
  state=sprintf("%s %s", $2, $3)
}
else if($1=="Pid:"){
  pid=sprintf("%s", $2)
}
}
END{ printf "<tr align=center><td> %s </td><td> %s </td><td> %s </td></tr>", name, state, pid;  }'

command_status () {
   printf "%s" "$(cat /proc/$1/status | sed -n 1,5p | awk "$awkProgramStatComm")"
}

# Print out system uptime in a readable format
awkUptimeComm='
function secToddhhmmss(secTotal)
{
  dayPart=int(secTotal / 86400); secTotal=(secTotal % 86400);
  hourPart=int(secTotal / 3600);
  minPart=int((secTotal % 3600) / 60);
  secPart=(secTotal % 3600) % 60;
  ddhhmmss(dayPart, hourPart, minPart, secPart);
}

function ddhhmmss(inday, inhour, inmin, insec)
{
   printf " days - %d  hh:mm:ss - %02d:%02d:%02d", inday, inhour, inmin, insec;
}
 
{ printf "Uptime: "; secToddhhmmss($1); }'

parse_uptime () {
  printf "%s" "$(cat /proc/uptime | awk "$awkUptimeComm")"
}


# Get stats from top on several TDT or Optima program processes
awkPROCcommand='
BEGIN{
processCt["ClampRun"]=0;processCt["ChunkWriter"]=0;processCt["Manager"]=0;
}
{
processCt[$12]++
if(processMem[$12] < $10)
  {
    processMem[$12] = $10
    processCPU[$12] = $9
  }
}
END{
    for (process in processCt){
	  printf "<tr align=center> <td> %s </td><td> %s </td><td> %s </td><td> %s </td></tr>",\
      process, processCt[process], processCPU[process], processMem[process];
    }
}'

topInfo_OptimaTDTProgs () {
  local topInfo="<table style=\"width:60%;\"><tr><th>Process</th><th># running</th><th>CPU use</th><th>Memory use</th></tr>\
  $(top -b -n 1 | grep -E "(Manager|ClampRun|ChunkWriter)" | awk "$awkPROCcommand")</table>"
  printf "%s" "$topInfo"
}
