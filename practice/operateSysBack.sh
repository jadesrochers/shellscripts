#! /bin/bash

# I already have perfectly good programs to do various file backups,
# This one is just going to focus on the operating system/ bootloader
# such that the system could be restored.
exec 1> /home/jadesrochers/bin/log/operateSysBack.log 2>&1

BACKLOC=/media/jadesrochers/Seagate_D1/
CURTIME=$(date "+%Y %j %H %M")
LITYEAR=$(cut -d " " -f 1 <<<"$CURTIME")
LITJDAY=$(cut -d " " -f 2 <<<"$CURTIME")
LITHOUR=$(cut -d " " -f 3 <<<"$CURTIME")
LITMIN=$(cut -d " " -f 4 <<<"$CURTIME")

# get the current year, mo, day in numerical format
declare -i CURYEAR=$((cut -d " " -f 1 | sed -r 's/^0*//') <<<"$CURTIME")
declare -i CURJDAY=$((cut -d " " -f 2 | sed -r 's/^0*//') <<<"$CURTIME")
declare -i CURHOUR=$((cut -d " " -f 3 | sed -r 's/^0*//') <<<"$CURTIME")
declare -i CURMIN=$((cut -d " " -f 4 | sed -r 's/^0*//') <<<"$CURTIME")

# a recommended backup arrangement based on ubuntu docs and forums.
#tar -cvpzf "${HOME}/${HOSTNAME}_backup.tgz" --exclude=/dev --exclude=/run
# --exclude=/proc --exclude=/mnt --exclude=/media --exclude=/sys --exclude=/home
# /
currBackRoot=($(find $BACKLOC -maxdepth 1 -regextype posix-egrep -regex "$BACKLOC${HOSTNAME}_Root_[[:digit:]]{4}_[[:digit:]]{3}_[[:digit:]]{2}_[[:digit:]]{2}$"))

if [[ ${#currBackRoot[@]} -gt 2 && ${#currBackRoot[@]} -lt 4  ]]; then
newBackRoot="${BACKLOC}${HOSTNAME}_Root_${LITYEAR}_${LITJDAY}_${LITHOUR}_${LITMIN}"
SORTEDroot=($(printf '%s\n' "${currBackRoot[@]}"|sort -r ))
	  # this for loop is a good candidate to turn into a function
	  for j2 in {0..2}; do
	  DIRDATE[$j2]=$(sed -r -e 's/.*\///' -e 's/.*[a-zA-Z]_//' <<<"${SORTEDroot[$j2]}");  echo "the current dirdate: ${DIRDATE[$j2]}"
	  declare -i DIRMIN=$(echo ${DIRDATE[$j2]} | cut -c 13-14 | sed -r 's/^0*//')
	  declare -i DIRHOUR=$(echo ${DIRDATE[$j2]} | cut -c 10-11 |  sed -r 's/^0*//')
	  declare -i DIRDAY=$(echo ${DIRDATE[$j2]} | cut -c 6-8 |  sed -r 's/^0*//')
	  declare -i DIRYEAR=$(echo ${DIRDATE[$j2]} | cut -c 1-4 |  sed -r 's/^0*//')
	  MINDIFF[$j2]=$(($CURMIN-$DIRMIN))
	  HOURDIFF[$j2]=$(($CURHOUR-$DIRHOUR))
	  DAYDIFF[$j2]=$(($CURJDAY-$DIRDAY)); echo "the curday: $CURJDAY and the dirday: $DIRDAY"
	  YEARDIFF[$j2]=$(($CURYEAR-$DIRYEAR)); echo "the curday: $CURYEAR and the dirday: $DIRYEAR"
	  done

	  if [[ ((${YEARDIFF[2]} -gt 0 && ${DAYDIFF[2]} -gt -363) || ${DAYDIFF[2]} -gt 2) && ((${YEARDIFF[0]} -gt 0 && ${DAYDIFF[0]} -gt -364) || ${DAYDIFF[0]} -gt 1) ]];  then

	  rsync -avzx  --exclude=/dev --exclude=/run --exclude=/proc --exclude=/mnt --exclude=/media --exclude=/sys --exclude=/home / ${SORTEDroot[2]}
	  mv ${SORTEDroot[2]} $newBackRoot
	  echo "Moved ${SORTEDroot[2]} to $newBackRoot"
	  else
	      echo "Root backup up to date for $HOSTNAME on $CURTIME"
	  fi
else
          numBackups=${#currBackRoot[@]}
	  numRemove=$(($numBackups-3))
	  numAdd=0; # ((numRemove--))
	  [[ numRemove -gt 0 ]] && for ((jrm=0; jrm<${numRemove}; jrm++)); do rm -rv ${currBackRoot[jrm]}; done
	  [[ numRemove -lt 0 ]] && numAdd=$(echo ${numRemove#-})
#          for j1 in ${currBackRoot[@]}; do rm -rv $j1; done
	 if [[ $numAdd -gt 0 ]]; then
	  for ((j3=0; j3<$numAdd; j3++)); do
          newBackRoot="${BACKLOC}${HOSTNAME}_Root_${LITYEAR}_${LITJDAY}_${LITHOUR}_${LITMIN}"
          rsync -avzx --exclude=/dev --exclude=/run --exclude=/proc --exclude=/mnt --exclude=/media --exclude=/sys --exclude=/home / $newBackRoot
	  TEMPMIN=$(sed -r -e 's/0([0-9])/\1/' <<< ${LITMIN})
	  ((TEMPMIN++))
	  [[ ${#TEMPMIN} -lt 2 ]] && TEMPMIN="0$TEMPMIN"
	  LITMIN=$TEMPMIN
	  echo "Created new backup $newBackRoot"
	  done
	 fi
fi

# a bit more explanation, /proc and /sys are virtual filesystems providing 
# windows into variables of the running kernel. /dev is tmpfs, so is /run.
# The others are mount locations. option --one-file-system will only 
# get files on the active partition, I do not have this onright now.

# to restore: only uncomment this code if actually doing restoration,
# it will overwrite all the parts of the system with the data in the archive.

# tar xvpzf "/media/jadesrochers/Seagate_D2/${HOSTNAME}_backup.tgz" -C / 

## then need to resotre directories that you did not backup, even though they 
## will be empty:

# mkdir /home/${USER}
# mkdir /proc
# mkdir /mnt  
# mkdir /media
# mkdir /sys
# mkdir /dev
# mkdir /run

# I have files from HOME backed up elsewhere, so they can be inserted 
# separately

# GRUB restore: for another time, but the guide is bookmarked.