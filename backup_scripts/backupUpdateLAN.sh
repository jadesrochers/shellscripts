#! /bin/bash
exec 1>> $/home/jadesrochers/bin/log/backupUpdateLAN.log 2>&1
printf %"s\n\n\n\n\n"
# give info about when the run was for the log file
currentTime=$(date "+%Y %j %H %M")
echo "Start of current run at: ${currentTime}"
printf %"s\n"

#list of ips and associated mac addresses
# Could automate generating these in another script, but it would need to be run when all machines are active.
declare -a ips=(192.168.2.10{9,7,5,3,1})
declare -a macs=("00:1F:29:9D:B1:59" "00:1F:29:9D:F4:EC" "00:1F:29:9D:54:33" "00:1F:29:9D:F4:E3" "60:eb:69:53:e9:ee")

# Scan for which machines are awake or not
# -c 2 limits to 2 pings, -t 2 waits for two seconds till timing out.
n=0;n1=0;n2=0; 
for ip in ${ips[@]}; do ping -c 2 -t 2 $ip > /dev/null; 
if [[ $? -eq 0 ]]; then
echo "$ip was up, doing nothing"
wasOn[$n1]=${ip}
((n1++))
else
echo "$ip was off, turning on"
sudo etherwake ${macs[$n]}
wasOff[$n2]=${ip}
fi
((n++))
done
sleep 90 # wait 90 seconds before doing anything to assure that the machines have booted
mount -a # mount all shares, which includes the hard drive on all the scrags
 
############################################## Backup section. Do both home and system (root)
backSource=(/mnt/{1701_Root,Scrag2_Root,Scrag3_Root,Scrag4_Root}/home/ /home/ /mnt/1701_Root/media/jadesrochers/Data_Store/Filed\ Pictures /mnt/1701_Root/media/jadesrochers/Data_Store/Music)
hostNames=(1701-A1 Scrag2 Scrag3 Scrag4 Scrag1 1701-A1 1701-A1)
backLocation=/mnt/Seagate_D2/
catName=(Home Home Home Home Home Pictures Music)

# a recommended backup arrangement based on ubuntu docs and forums.
#tar -cvpzf "${HOME}/${HOSTNAME}_backup.tgz" --exclude=/dev --exclude=/run
# --exclude=/proc --exclude=/mnt --exclude=/media --exclude=/sys --exclude=/home
# /
numBackups=$((${#catName[@]}-1))
for j in {0..${numBackups}}; do

# get the current time every loop so that the timestamp on the backup reflects when it was started
currentTime=$(date "+%Y %j %H %M")
LITYEAR=$(cut -d " " -f 1 <<<"$currentTime")
LITJDAY=$(cut -d " " -f 2 <<<"$currentTime")
LITHOUR=$(cut -d " " -f 3 <<<"$currentTime")
LITMIN=$(cut -d " " -f 4 <<<"$currentTime")

# get the current year, mo, day in numerical format
declare -i CURYEAR=$((cut -d " " -f 1 | sed -r 's/^0*//') <<<"$currentTime")
declare -i CURJDAY=$((cut -d " " -f 2 | sed -r 's/^0*//') <<<"$currentTime")
declare -i CURHOUR=$((cut -d " " -f 3 | sed -r 's/^0*//') <<<"$currentTime")
declare -i CURMIN=$((cut -d " " -f 4 | sed -r 's/^0*//') <<<"$currentTime")

#sourceDir=$(sed -r -e 's/[^\/].*\///' -e 's/(.*[a-zA-Z])_/\1/' <<<"${j}") extract source from path
currBackHome=($(find $backLocation -maxdepth 1 -regextype posix-egrep -regex "$backLocation${hostNames[${j}]}_${catName[${j}]}_[[:digit:]]{4}_[[:digit:]]{3}_[[:digit:]]{2}_[[:digit:]]{2}$"))

 if [[ ${#currBackHome[@]} -gt 1 && ${#currBackHome[@]} -lt 3  ]]; then
 echo "there were two existing directories"
 newBackHome="${backLocation}${hostNames[$j]}_${catName[${j}]}_${LITYEAR}_${LITJDAY}_${LITHOUR}_${LITMIN}"
 sortedHome=($(printf '%s\n' "${currBackHome[@]}"|sort -r ))
	   # this for loop is a good candidate to turn into a function
	   for j2 in {0..1}; do
	   DIRDATE[$j2]=$(sed -r -e 's/.*\///' -e 's/.*[a-zA-Z]_//' <<<"${sortedHome[$j2]}");  echo "the current dirdate: ${DIRDATE[$j2]}"
	   declare -i DIRMIN=$(echo ${DIRDATE[$j2]} | cut -c 13-14 | sed -r 's/^0*//')
	   declare -i DIRHOUR=$(echo ${DIRDATE[$j2]} | cut -c 10-11 |  sed -r 's/^0*//')
	   declare -i DIRDAY=$(echo ${DIRDATE[$j2]} | cut -c 6-8 |  sed -r 's/^0*//')
	   declare -i DIRYEAR=$(echo ${DIRDATE[$j2]} | cut -c 1-4 |  sed -r 's/^0*//')
	   MINDIFF[$j2]=$(($CURMIN-$DIRMIN))
	   HOURDIFF[$j2]=$(($CURHOUR-$DIRHOUR))
	   DAYDIFF[$j2]=$(($CURJDAY-$DIRDAY)); echo "the current day: $CURJDAY and the day of the existing directory: $DIRDAY"
	   YEARDIFF[$j2]=$(($CURYEAR-$DIRYEAR)); echo "the current year: $CURYEAR and the year of the existing directory: $DIRYEAR"
	   done
	   
	   # This can run once per day most effectively. This logical statement looks for the oldest backup to be greater than two days 
	   # old and the newest to be at least a day old if an update is going to be done.
	   if [[ ((${YEARDIFF[1]} -gt 0 && ${DAYDIFF[1]} -gt -363) || (${DAYDIFF[1]} -gt 1)) && ((${YEARDIFF[0]} -gt 0 && ${DAYDIFF[0]} -gt -364) || ${DAYDIFF[0]} -gt 0)]];  then

	    # twice a year run rsync with the delete option to remove files that have disappeared.
	    # two days should be enough, but running three to be sure.   
	    if [[ (${CURJDAY} -gt 178 && ${CURJDAY} -lt 182) || (${CURJDAY} -gt 358 && ${CURJDAY} -lt 362) ]]; then 
	    echo "updating ${sortedHome[1]} deleting files that no longer exist"
	    rsync -azx --delete ${backSource[${j}]}  ${sortedHome[1]}
	    # options: a - archive, equals rlptgoD; v - verbose, z - compress, x - do not cross filesystems boundaries.
	    # --delete - remove files that no longer exist in the source
	    else
	    echo "updating ${sortedHome[1]} retaining all files"
	    rsync -azx ${backSource[${j}]}  ${sortedHome[1]}
#    	    rsync -avzx  --exclude=/dev --exclude=/run --exclude=/proc --exclude=/mnt --exclude=/media --exclude=/sys --exclude=/home / ${sortedHome[1]}
	    fi
	    mv ${sortedHome[1]} $newBackHome
	    echo "Moved ${sortedHome[1]} to $newBackHome"
	   else
		echo "Home backup up to date for $hostNames[$j] on $currentTime"
	   fi
 else
	   numBackups=${#currBackHome[@]}
           echo "There were $numBackups existing backups, now going to remove or create to get to two"
	   numRemove=$(($numBackups-2))
	   numAdd=0; # ((numRemove--))
	   [[ numRemove -gt 0 ]] && for ((jrm=0; jrm<${numRemove}; jrm++)); do echo "removing ${currBackHome[jrm]}"; rm -r ${currBackHome[jrm]}; done
	   [[ numRemove -lt 0 ]] && numAdd=$(echo ${numRemove#-})
 #          for j1 in ${currBackHome[@]}; do rm -rv $j1; done
	  if [[ $numAdd -gt 0 ]]; then
	   for ((j3=0; j3<$numAdd; j3++)); do
	   newBackHome="${backLocation}${hostNames[$j]}_${catName[${j}]}_${LITYEAR}_${LITJDAY}_${LITHOUR}_${LITMIN}"
	   echo "Creating new backup $newBackHome"
	   rsync -azx ${backSource[${j}]} $newBackHome
	   TEMPMIN=$(sed -r -e 's/0([0-9])/\1/' <<< ${LITMIN})
	   ((TEMPMIN++))
	   [[ ${#TEMPMIN} -lt 2 ]] && TEMPMIN="0$TEMPMIN"
	   LITMIN=$TEMPMIN
	   echo "Created new backup $newBackHome"
	   done
	  fi
 fi
done
############################################### end backup of home/root section

############################################### Update machines
# do the local machine first, as I dont need ssh for that
apt-get --yes --force-yes update
apt-get --yes --force-yes upgrade
# do all the others with commands given to ssh


############################################### Update section end 

# Scan for which machines are awake or not
# -c 2 limits to 2 pings, -t 2 waits for two seconds till timing out.
for ip in ${wasOff[@]}; do
echo "$ip was powered down when script began, shutting it down again"
ssh backuponly@$ip -i /home/backuponly/.ssh/backuponly_rsa "sudo shutdown -h now"
# ssh backuponly@$ip 'sudo poweroff' #single quotes to prevent local shell evaluation. And then I realized none of this will work resulting in the marathon to get the backuponly on all the other computers with sudoless permission to shutdown.
done

#Brief set of notices about computers that were already on when the script started.
for ip in ${wasOn[@]}; do
echo "$ip was on, leaving in that state"
done

# give info about the end of the run for the log file.
printf %"s\n"
currentTime=$(date "+%Y %j %H %M")
echo "End of current run at: ${currentTime}"
