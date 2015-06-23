#! /bin/bash
exec 1>> /home/jadesrochers/bin/shellScripts/backup_scripts/log/backupToExternal.log 2>&1
printf %"s\n\n\n\n\n"
# give info about when the run was for the log file
currentTime=$(date --rfc-3339=seconds)
printf "%s\n" "Start of current run at: ${currentTime}"
printf %"s\n"

############################################## Backup section. Do both home and system (root)
declare -a backSource=("/home/jadesrochers" "/media/jadesrochers/Data_Store/Filed Pictures/" "/media/jadesrochers/Data_Store/Music/" "/")
hostNames=(1701-A1 1701-A1 1701-A1 1701-A1)
backLocation=/media/jadesrochers/Seagate_D2/
catName=(Home Pictures Music Root)
sudo mount -a
if [[ -d "$backLocation" ]]; then 
    printf %"sThe backup directory exists\n\n";
else
    exit
fi
# set the number of backups you want to have
numBackups=2; backless=$(((numBackups-1))); backmore=$(((numBackups+1)));
numSourceLocs=$((${#catName[@]}-1))

# set -x
for j in $(seq 0 $numSourceLocs); do
    # get the current time every loop so that the timestamp on the backup reflects when it was started
    currentTime=$(date --rfc-3339=seconds)
    currentTimeStr=$( echo $currentTime | sed -r 's/[ \t]+/_/')
    currBack=($(find $backLocation -maxdepth 1 -regextype posix-egrep -regex "$backLocation${hostNames[${j}]}_${catName[${j}]}_[-_[:digit:]:]{24,26}$"))

    if [[ ${#currBack[@]} -gt $backless && ${#currBack[@]} -lt $backmore  ]]; then
	printf "%s\n" "there were the correct number of existing directories"
	newBack="${backLocation}${hostNames[$j]}_${catName[${j}]}_$currentTimeStr"
	sortedCurBack=($(printf '%s\n' "${currBack[@]}"|sort -r ))
	
	# operations to get the dates from existing backups, calculate the ages
	DirDates=($(for k in ${sortedCurBack[@]}; do sed -r -e 's/.*\///' -e 's/.*[a-zA-Z]_//' <<<"$k"; done))
	# use the field separator to allow array creation ignoring spaces 
	IFS_back=$IFS; IFS="*"
	DirCalcDates=($(for k in ${DirDates[@]}; do printf "%s*" "$(sed -r 's/_/ /' <<<$k)"; done));
	CurVsDirTimeDiff=($(for k in ${DirCalcDates[@]}; do printf "%s*" "$(($(date --date="$currentTime" +%s)-$(date --date="$k" +%s)))"; done))
	IFS=$IFS_back

	# use the age of the oldest and newest to determine if a backup will be conducted
	NumDiffs=$(((${#CurVsDirTimeDiff[@]}-1)))
	if [[ ${CurVsDirTimeDiff[$NumDiffs]} -gt 7000 && ${CurVsDirTimeDiff[0]} -gt 3600 ]];  then
	    curJDay=$(date +%j | sed -r 's/^0+//')
	    # if the backup source exists, resync it deleting lost files. Git takes care of rolling back
	    if [[ -d ${backSource[$j]} ]]; then
		if [[ "${backSource[$j]}" = "/" ]]; then  # use this if doing root backup
		    printf "%s\n" "updating root backup: ${sortedCurBack[NumDiffs]} "
		    rsync -aAX  --delete --delete-excluded --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / ${sortedCurBack[NumDiffs]}
		else
		    printf "%s\n" "updating ${sortedCurBack[$NumDiffs]} deleting files that no longer exist"
		    sudo rsync -azx --delete "${backSource[${j}]}"  ${sortedCurBack[$NumDiffs]}
		fi
		mv ${sortedCurBack[NumDiffs]} $newBack
		printf "%s\n" "Moved ${sortedCurBack[NumDiffs]} to $newBack\n"
            else
		printf "%s\n" "there was no ${backSource[$j]} folder to back up right now, problem"    
	    fi    
	else
	    printf "%s\n\n" "${catName[$j]} backup up to date for ${hostNames[$j]} on $currentTime"
	fi
    else  
	numSourceLocs=${#currBack[@]}
        printf "%s\n" "There were $numSourceLocs existing backups, now going to remove or create to get to two"
	numRemove=$(($numSourceLocs-2))
	numAdd=0
	[[ numRemove -gt 0 ]] && for ((jrm=0; jrm<${numRemove}; jrm++)); do printf "%s\n\n" "removing ${currBack[jrm]}"; rm -r ${currBack[jrm]}; done
	[[ numRemove -lt 0 ]] && numAdd=$(echo ${numRemove#-})
	if [[ $numAdd -gt 0 ]]; then
	    for ((k=0; k<$numAdd; k++)); do
		newBack="${backLocation}${hostNames[$j]}_${catName[${j}]}_$currentTimeStr"
		printf "%s\n" "Creating new backup $newBack"
		if [[ "${backSource[$j]}" = "/" ]]; then   # if creating a root backup
		    rsync -aAX  --delete  --delete-excluded --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / ${sortedCurBack[NumDiffs]}
		else
		    sudo rsync -azx "${backSource[${j}]}" $newBack
		fi
		printf "%s\n\n" "Created new backup $newBack"
	    done
	fi
    fi
done
# set +x
############################################### end backup of home/root section

############################################### Update machines
# do all the debian/ubuntu based with apt-get commands given to ssh
# declare -a ips=(192.168.20.11)
# for j in ${ips[@]}; do
#     ssh backuponly@$j -i /home/backuponly/.ssh/backuponly_rsa "sudo apt-get --yes --force-yes update"
#     ssh backuponly@$j -i /home/backuponly/.ssh/backuponly_rsa "sudo apt-get --yes --force-yes upgrade"
#     ssh backuponly@$j -i /home/backuponly/.ssh/backuponly_rsa "sudo apt-get --yes --force-yes autoclean"
#     # if the update requires a reboot, check for that here, and then do it if needed  
#     needReboot=$(ssh backuponly@$j -i /home/backuponly/.ssh/backuponly_rsa "ls /var/run/" | grep reboot-required)
#     if [[ -n $needReboot ]]; then ssh backuponly@$j -i /home/backuponly/.ssh/backuponly_rsa "sudo shutdown -r now"; fi
# done 

############################################### Update section end 

printf %"s\n"
currentTime=$(date --rfc-3339=seconds)
printf "%s\n" "End of current run at: ${currentTime}"

