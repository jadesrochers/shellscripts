#! /bin/bash

# do a system backup to a remote location. In this case, the 
# external drives attached to 1701-A1. Will rsync the home folders
# as document storage, and backup the whole hard drive with tar.
# This could also be useful for cloning the debian system If I
# want it on another one of my laptops.
exec 1>> /home/jadesrochers/bin/log/sshBack.log 2>&1
printf %"s\n\n\n\n\n"
remoteNames=("Scrag1" "Scrag2")
remoteIPs=("192.168.30.103" "192.168.30.105")
remoteUser=backuponly
fileLoc="/media/jadesrochers/Seagate_D2/"
sysLoc="/media/jadesrochers/Seagate_D1/"
# thinking it out: get remote host name first.
# then do a backup over the connection using rsync
# with the usage path to the remote directory 
# need to use the correct login user (backuponly)
# and set paths for the log file and destination of the backups.
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

# set -x
for j in "${remoteIPs[@]}"; do
# enter the first statement if contact witht the host wast successful
# the $? is the return code from the most recent command, which tests whether I can login or not.
ssh -i /home/backuponly/.ssh/id_rsa  -q $remoteUser@$j exit
    if [[ $? -eq 0  ]]; then
    remoteName=$(ssh -i /home/backuponly/.ssh/id_rsa ${remoteUser}@$j hostname)
    safeName=$(echo $remoteName | sed 's/[-[\.*^$(){}?+|/]/_/g')
    backDests=("${fileLoc}${safeName}_Home_" "${sysLoc}${safeName}_Root_")    
    N=1
    for j1 in "${backDests[@]}"; do
    currBack=($(find ${j1%/*} -maxdepth 1 -regextype posix-egrep -regex "${j1}[[:digit:]]{4}_[[:digit:]]{3}_[[:digit:]]{2}_[[:digit:]]{2}$"))
    echo ${currBack[@]}; 

     if [[ ${#currBack[@]} -gt 2 && ${#currBack[@]} -lt 4  ]]; then
     newBack="${j1}${LITYEAR}_${LITJDAY}_${LITHOUR}_${LITMIN}"
     SORTEDback=($(printf '%s\n' "${currBack[@]}"|sort -r ))
	  # this for loop is a good candidate to turn into a function
	  for j2 in {0..2}; do
	  DIRDATE[$j2]=$(sed -r -e 's/.*\///' -e 's/.*[a-zA-Z]_//' <<<"${SORTEDback[$j2]}"); echo "the current dirdate: ${DIRDATE[$j2]}"
	  declare -i DIRMIN=$(echo ${DIRDATE[$j2]} | cut -c 13-14 | sed -r 's/^0*//')
	  declare -i DIRHOUR=$(echo ${DIRDATE[$j2]} | cut -c 10-11 |  sed -r 's/^0*//')
	  declare -i DIRDAY=$(echo ${DIRDATE[$j2]} | cut -c 6-8 |  sed -r 's/^0*//')
	  declare -i DIRYEAR=$(echo ${DIRDATE[$j2]} | cut -c 1-4 |  sed -r 's/^0*//')
	  MINDIFF[$j2]=$(($CURMIN-$DIRMIN));
	  HOURDIFF[$j2]=$(($CURHOUR-$DIRHOUR));
	  DAYDIFF[$j2]=$(($CURJDAY-$DIRDAY)); echo "the curday: $CURJDAY and the dirday: $DIRDAY"
	  YEARDIFF[$j2]=$(($CURYEAR-$DIRYEAR)); echo "the curday: $CURYEAR and the dirday: $DIRYEAR"
	  done
	  
	  echo "Daydiff 0 is ${DAYDIFF[0]} and daydiff 2 is ${DAYDIFF[2]}"
	  echo "Yeardiff 0 is ${YEARDIFF[0]} and yeardiff 2 is ${YEARDIFF[2]}"
	  if [[ ((${YEARDIFF[2]} -gt 0 && ${DAYDIFF[2]} -gt -362) || ${DAYDIFF[2]} -gt 3) && ((${YEARDIFF[0]} -gt 0 && ${DAYDIFF[0]} -gt -364) || ${DAYDIFF[0]} -gt 1) ]];  then
	      # For the first loop for each ip, do home backup
	      if [[ N -eq 1 ]]; then
	      rsync -avz -e "ssh -i /home/backuponly/.ssh/id_rsa -l ${remoteUser}" --rsync-path=/home/backuponly/rsync-wrapper.sh "${remoteUser}@$j:/home/" ${SORTEDback[2]}
	      # For the second loop on each ip, do the root/system backup
	      elif [[ N -eq 2 ]]; then
	      rsync -avzx --delete -e "ssh -i /home/backuponly/.ssh/id_rsa -l ${remoteUser}" --rsync-path=/home/backuponly/rsync-wrapper.sh --exclude=/dev --exclude=/run --exclude=/proc --exclude=/sys "${remoteUser}@$j:/" ${SORTEDback[2]}
	      else
		  echo "N was not 1 or 2"
	      fi
	  mv ${SORTEDback[2]} $newBack
	  echo "Updated and moved ${SORTEDback[2]} to $newBack"
	  else 
	      echo "No updates to be made to $j1/$safeName backups on $CURTIME"
	  fi

     else
     echo "unexpected number of backups, get back to three"
     numBackups=${#currBack[@]}; echo "Current # of directories: $numBackups"
     numRemove=$(($numBackups-3)); echo "Number of dirs to remove: $numRemove"
     numAdd=0; # ((numRemove--))
     [[ numRemove -gt 0 ]] && for ((jrm=0; jrm<${numRemove}; jrm++)); do rm -rv ${currBack[jrm]}; done
     [[ numRemove -lt 0 ]] && numAdd=$(echo ${numRemove#-})
#	for j3 in ${currBack[@]}; do rm -rv $j3; done
      if [[ $numAdd -gt 0 ]]; then
	for ((j4=0; j4<$numAdd; j4++)); do
	   newBack="${j1}${LITYEAR}_${LITJDAY}_${LITHOUR}_${LITMIN}"
	      if [[ N -eq 1 ]]; then
	      rsync -avz -e "ssh -i /home/backuponly/.ssh/id_rsa -l ${remoteUser}" --rsync-path=/home/backuponly/rsync-wrapper.sh "${remoteUser}@$j:/home/" $newBack
	      elif [[ N -eq 2 ]]; then
	      rsync -avzx --delete -e "ssh -i /home/backuponly/.ssh/id_rsa -l ${remoteUser}" --rsync-path=/home/backuponly/rsync-wrapper.sh --exclude=/dev --exclude=/run --exclude=/proc --exclude=/sys "${remoteUser}@$j:/" $newBack
	      else
		  echo "making it beyond N=2, problem with incrementer"
	      fi
	   TEMPMIN=$(sed -r -e 's/0([0-9])/\1/' <<< ${LITMIN})
	   ((TEMPMIN++))
	   [[ ${#TEMPMIN} -lt 2 ]] && TEMPMIN="0$TEMPMIN"
	   LITMIN=$TEMPMIN
	done
      fi
     ((LITMIN-2))
     fi
    echo $N
    ((N++))
    done

    else
	echo "Could not connect to $j, moving to the next connection"
    fi

done
# set +x

printf %"s\n"
CURTIME=$(date "+%Y %j %H %M")
echo "End of current run at: ${CURTIME}"

