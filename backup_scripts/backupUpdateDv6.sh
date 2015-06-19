#! /bin/bash
exec 1>> /home/jadesrochers/bin/shellscripts/backup_scripts/log/backupUpdateDv6.log 2>&1
printf %"s\n\n\n\n\n"
# give info about when the run was for the log file
currentTime=$(date "+%Y %j %H %M")
echo "Start of current run at: ${currentTime}"
printf %"s\n"
############################################## Backup section. Do both home and system (root)
declare -a backSource=("/mnt/1701_Root/home/" "/mnt/1701_Root/media/jadesrochers/Data_Store/Filed Pictures/" "/mnt/1701_Root/media/jadesrochers/Data_Store/Music/")
hostNames=(1701-A1 1701-A1 1701-A1)
backLocation=/mnt/Seagate_D2/
catName=(Home Pictures Music)
sudo mount -a
# a recommended backup arrangement based on ubuntu docs and forums.
#tar -cvpzf "${HOME}/${HOSTNAME}_backup.tgz" --exclude=/dev --exclude=/run
# --exclude=/proc --exclude=/mnt --exclude=/media --exclude=/sys --exclude=/home
# /
numBackups=$((${#catName[@]}-1))
# set -x
for j in $(seq 0 $numBackups); do

# get the current time every loop so that the timestamp on the backup reflects when it was started
currentTime=$(date "+%Y %j %H %M")
timeArray=($currentTime)

# get the current year, mo, day in numerical format with a loop
curTime=($(for j in ${timeArray[@]}; do sed -r 's/^0*//' <<<$j; done))

#sourceDir=$(sed -r -e 's/[^\/].*\///' -e 's/(.*[a-zA-Z])_/\1/' <<<"${j}") extract source from path
currBackHome=($(find $backLocation -maxdepth 1 -regextype posix-egrep -regex "$backLocation${hostNames[${j}]}_${catName[${j}]}_[[:digit:]]{4}_[[:digit:]]{3}_[[:digit:]]{2}_[[:digit:]]{2}$"))

 if [[ ${#currBackHome[@]} -gt 1 && ${#currBackHome[@]} -lt 3  ]]; then
 echo "there were two existing directories"
 newBackHome="${backLocation}${hostNames[$j]}_${catName[${j}]}_${timeArray[0]}_${timeArray[1]}_${timeArray[2]}_${timeArray[3]}"
 sortedHome=($(printf '%s\n' "${currBackHome[@]}"|sort -r ))
	   # this for loop is a good candidate to turn into a function
	   for j2 in {0..1}; do
	   DIRDATE=$(sed -r -e 's/.*\///' -e 's/.*[a-zA-Z]_//' <<<"${sortedHome[$j2]}");  echo "the current dirdate: ${DIRDATE[$j2]}"
	   IFS_back=$IFS; IFS='_';
	   dirDate=($DIRDATE); IFS=$IFS_back;
	   dirTimes=($(for j in ${dirDate[@]}; do sed -r 's/^0*//' <<<$j; done))
	   # declare -i DIRMIN=$(echo ${DIRDATE[$j2]} | cut -c 13-14 | sed -r 's/^0*//')
	   # declare -i DIRHOUR=$(echo ${DIRDATE[$j2]} | cut -c 10-11 |  sed -r 's/^0*//')
	   # declare -i DIRDAY=$(echo ${DIRDATE[$j2]} | cut -c 6-8 |  sed -r 's/^0*//')
	   # declare -i DIRYEAR=$(echo ${DIRDATE[$j2]} | cut -c 1-4 |  sed -r 's/^0*//')
	   MINDIFF[$j2]=$((${curTime[3]}-${dirTimes[3]}))
	   HOURDIFF[$j2]=$((${curTime[2]}-${dirTimes[2]}))
	   DAYDIFF[$j2]=$((${curTime[1]}-${dirTimes[1]})); echo "the current day: $CURJDAY and the day of the existing directory: $DIRDAY"
	   YEARDIFF[$j2]=$((${curTime[0]}-${dirTimes[0]})); echo "the current year: $CURYEAR and the year of the existing directory: $DIRYEAR"
	   done
	   
	   # This can run once per day most effectively. This logical statement looks for the oldest backup to be greater than two days 
	   # old and the newest to be at least a day old if an update is going to be done.
	   if [[ ((${YEARDIFF[1]} -gt 0 && ${DAYDIFF[1]} -gt -363) || (${DAYDIFF[1]} -gt 1)) && ((${YEARDIFF[0]} -gt 0 && ${DAYDIFF[0]} -gt -364) || ${DAYDIFF[0]} -gt 0)]];  then

	    # twice a year run rsync with the delete option to remove files that have disappeared.
	    # two days should be enough, but running three to be sure.   
	    if [[ -d ${backSource[$j]} ]]; then    
	     if [[ (${curTime[1]} -gt 178 && ${curTime[1]} -lt 182) || (${curTime[1]} -gt 358 && ${curTime[1]} -lt 362) ]]; then 
	     echo "updating ${sortedHome[1]} deleting files that no longer exist"
	     sudo rsync -azx --delete "${backSource[${j}]}"  ${sortedHome[1]}
	     # options: a - archive, equals rlptgoD; v - verbose, z - compress, x - do not cross filesystems boundaries.
	     # --delete - remove files that no longer exist in the source
	     else
	     echo "updating ${sortedHome[1]} retaining all files"
	     sudo rsync -azx "${backSource[${j}]}"  ${sortedHome[1]}
 #    	    rsync -avzx  --exclude=/dev --exclude=/run --exclude=/proc --exclude=/mnt --exclude=/media --exclude=/sys --exclude=/home / ${sortedHome[1]}
	     fi
            mv ${sortedHome[1]} $newBackHome
            echo "Moved ${sortedHome[1]} to $newBackHome"
            else
	    echo "there was no ${backSource[$j]} folder to back up right now, 1701 was probably off"    
	    fi    
	   else
	   echo "$catName backup up to date for ${hostNames[$j]} on $currentTime"
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
	   newBackHome="${backLocation}${hostNames[$j]}_${catName[${j}]}_${timeArray[0]}_${timeArray[1]}_${timeArray[2]}_${timeArray[3]}"
	   echo "Creating new backup $newBackHome"
	   sudo rsync -azx "${backSource[${j}]}" $newBackHome
	   TEMPMIN=$(sed -r -e 's/0([0-9])/\1/' <<< ${timeArray[3]})
	   ((TEMPMIN++))
	   [[ ${#TEMPMIN} -lt 2 ]] && TEMPMIN="0$TEMPMIN"
	   timeArray[3]=$TEMPMIN
	   echo "Created new backup $newBackHome"
	   done
	  fi
 fi
done
# set +x
############################################### end backup of home/root section

############################################### Update machines
# do all the debian/ubuntu based with apt-get commands given to ssh
declare -a ips=(192.168.20.11)
for j in ${ips[@]}; do
ssh backuponly@$j -i /home/backuponly/.ssh/backuponly_rsa "sudo apt-get --yes --force-yes update"
ssh backuponly@$j -i /home/backuponly/.ssh/backuponly_rsa "sudo apt-get --yes --force-yes upgrade"
ssh backuponly@$j -i /home/backuponly/.ssh/backuponly_rsa "sudo apt-get --yes --force-yes autoclean"
# if the update requires a reboot, check for that here, and then do it if needed  
needReboot=$(ssh backuponly@$j -i /home/backuponly/.ssh/backuponly_rsa "ls /var/run/" | grep reboot-required)
if [[ -n $needReboot ]]; then ssh backuponly@$j -i /home/backuponly/.ssh/backuponly_rsa "sudo shutdown -r now"; fi
done 

############################################### Update section end 

printf %"s\n"
currentTime=$(date "+%Y %j %H %M")
echo "End of current run at: ${currentTime}"

