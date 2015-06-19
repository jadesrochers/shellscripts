#!/bin/bash
# determine if backups have been created, if not put them in place,

# if so follow an update schedule so there are older backups in the 
# case of a catastrophe that corrupts or saves damage to a newer one.

exec 1>> $HOME/bin/log/redundantBackup.log 2>&1
printf %"s\n\n\n\n\n"
CURTIME=$(date "+%Y %j %H %M")
echo "Start of current run at: ${CURTIME}"
printf %"s\n"
# CURHOST=$HOSTNAME
# takes the host name and makes sure it can be part of file name
# by replacing any objectionable characters with _
SAFEHOST=$(echo $HOSTNAME | sed 's/[-[\.*^$(){}?+|/]/_/g')
declare -a BACKLOCS=("/media/jadesrochers/Seagate_D1" "/media/jadesrochers/Seagate_D2" )

HOMEDIR=/home
STORAGEDRIVE="/media/jadesrochers/Data_Store/"
declare -a BACKDATES=("_Curr" "_1P" "_10P")
J1MAX=${#BACKDIRS[@]}

# instead of looping to create these, some brace expansions do
# just fine and save a lot of code. Loops were nice, they are 
# saved in the examples part of my bash guide.
declare -a SOURCELOCS=("$HOMEDIR" "${STORAGEDRIVE}"{"Filed Pictures","Music"})
declare -a BACKCOMPLETE=({"${BACKLOCS[0]}","${BACKLOCS[1]}"}"/${SAFEHOST}_"{"Home","Pictures","Music"}) # bash tolerates line continuation with commands.
# it hates them with comments, if you want new comment line, 
# need the symbol on it, never try and continue them.

# get the current year, mo, day in numerical format
declare -i CURYEAR=$((cut -d " " -f 1 | sed -r 's/^0*//') <<<"$CURTIME")
declare -i CURJDAY=$((cut -d " " -f 2 | sed -r 's/^0*//') <<<"$CURTIME")
declare -i CURHOUR=$((cut -d " " -f 3 | sed -r 's/^0*//') <<<"$CURTIME")
declare -i CURMIN=$((cut -d " " -f 4 | sed -r 's/^0*//') <<<"$CURTIME")

# also store the date in literal form to use renaming folders or creating them.
LITYEAR=$(cut -d " " -f 1 <<<"$CURTIME")
LITJDAY=$(cut -d " " -f 2 <<<"$CURTIME")
LITHOUR=$(cut -d " " -f 3 <<<"$CURTIME")
LITMIN=$(cut -d " " -f 4 <<<"$CURTIME")

# what this loop will do is check all the backup dir destinations
# to see what is there. If there is nothing, backup is created.
# If is exists, check for the past ones, update any as neccesary.
# the braces and @ make sure all values in array are used
# set -x
N1=0
for j in ${BACKCOMPLETE[@]}; do
# may be able to shorten this, could not make it work without
# naming external drive as search directory
declare -a EXISTBACKS=($(find ${j%/*} -maxdepth 1 -regextype posix-egrep -regex "${j}_[[:digit:]]{4}_[[:digit:]]{3}_[[:digit:]]{2}_[[:digit:]]{2}$"))
 if [[ ${#EXISTBACKS[@]} -gt 2 && ${#EXISTBACKS[@]} -lt 4  ]]; then
     echo "there were three existing directories"
     # use sort with -n and -k command to sort these. Not sure if it will
     # work, but it seems worth a try.
     # this seems to take output from the variable and give it to function.
     # both these work, the second seems to work better.
     sort1=($(sort <<<"${EXISTBACKS[*]}"))
     SORTED=($(printf '%s\n' "${EXISTBACKS[@]}"|sort -r ))
     N=1  
     for j1 in ${SORTED[@]}; do
	 DIRDATE=$(sed -r -e 's/.*\///' -e 's/.*[a-zA-Z]_//' <<<"$j1")
	 declare -i DIRMIN=$(echo $DIRDATE | cut -c 13-14 | sed -r 's/^0*//')
  	 declare -i DIRHOUR=$(echo $DIRDATE | cut -c 10-11 |  sed -r 's/^0*//')
	 declare -i DIRDAY=$(echo $DIRDATE | cut -c 6-8 |  sed -r 's/^0*//')
	 declare -i DIRYEAR=$(echo $DIRDATE | cut -c 1-4 |  sed -r 's/^0*//')
	 MINDIFF=$(($CURMIN-$DIRMIN))
	 HOURDIFF=$(($CURHOUR-$DIRHOUR))
	 DAYDIFF=$(($CURJDAY-$DIRDAY))
	 YEARDIFF=$(($CURYEAR-$DIRYEAR))
	 UPDATE=0
	if [[ $N -eq 1 ]]; then
	    # case for hourly updated backup
	    if [[ $YEARDIFF -gt 0 || $DAYDIFF -gt 0 || $HOURDIFF -gt 1 || ($HOURDIFF -gt 0 && $MINDIFF -gt -1) ]]; then
		echo "The hourly file should be updated"
		# backup with deletion of files that no longer exist in source.
		rsync -avz --delete "${SOURCELOCS[$((N1))]}/" $j1
		# rename file to reflect current time.
		NEWNAME=$( echo $j1 | sed -r 's/(_[^_]+_[^_]+_[^_]+_[^_]+)$//')
		# if statement short form, checking length of minute field.
		# Should not matter here but will when I add to it.
		[[ ${#LITMIN} -lt 2 ]] && LITMIN="0$LITMIN"

		# the following prevents moving to existing dir. This
		# might make a good function, as it gets repeated x3.
		RENAMED="${NEWNAME}_${LITYEAR}_${LITJDAY}_${LITHOUR}_${LITMIN}"
		[[ -d $RENAMED ]] && TEMPMIN=$(sed -r -e 's/0([0-9])/\1/' <<< ${LITMIN})
		
		while [[ -d $RENAMED ]]; do
		((TEMPMIN--))
		[[ ${#TEMPMIN} -lt 2 ]] && TEMPMIN="0$TEMPMIN"
		RENAMED="${NEWNAME}_${LITYEAR}_${LITJDAY}_${LITHOUR}_${TEMPMIN}"
		TEMPMIN=$(sed -r -e 's/0([0-9])/\1/' <<< ${TEMPMIN})
		done
	        mv $j1 $RENAMED
		echo "Moved $j1 to $RENAMED"
	    fi
	    ((N++));
	elif [[ $N -eq 2 ]]; then
	    # case for daily updated backup
	    if [[ $YEARDIFF -gt 0 || $DAYDIFF -gt 1 || ($DAYDIFF -gt 0 && $HOURDIFF -gt 0) ]]; then
		echo "The Daily file should be updated"
		rsync -avz "${SOURCELOCS[$((N1))]}/" $j1
		((LITMIN--))
		[[ ${#LITMIN} -lt 2 ]] && LITMIN="0$LITMIN"
		RENAMED="${NEWNAME}_${LITYEAR}_${LITJDAY}_${LITHOUR}_${LITMIN}"
		[[ -d $RENAMED ]] && TEMPMIN=$(sed -r -e 's/0([0-9])/\1/' <<< ${LITMIN})
		while [[ -d $RENAMED ]]; do
		((TEMPMIN--))
		[[ ${#TEMPMIN} -lt 2 ]] && TEMPMIN="0$TEMPMIN"
		RENAMED="${NEWNAME}_${LITYEAR}_${LITJDAY}_${LITHOUR}_${TEMPMIN}"
		TEMPMIN=$(sed -r -e 's/0([0-9])/\1/' <<< ${TEMPMIN})
		done
		mv $j1 $RENAMED
		echo "Moved $j1 to $RENAMED"
	    fi
    	    ((N++));
	else 
	    # case for monthly updated backup
	    if [[ $YEARDIFF -gt 1 || ($YEARDIFF -gt 0 && $DAYDIFF -gt -335)  || ($DAYDIFF -gt 30) ]]; then
		echo "the monthly file should be updated"
		# backup without deletion, copy only directory contents (trailing /)
		rsync -avz "${SOURCELOCS[$((N1))]}/" $j1
		((LITMIN--))
		[[ ${#LITMIN} -lt 2 ]] && LITMIN="0$LITMIN"
		RENAMED="${NEWNAME}_${LITYEAR}_${LITJDAY}_${LITHOUR}_${LITMIN}"
		[[ -d $RENAMED ]] && TEMPMIN=$(sed -r -e 's/0([0-9])/\1/' <<< ${LITMIN})
		while [[ -d $RENAMED ]]; do
		((TEMPMIN--))
		[[ ${#TEMPMIN} -lt 2 ]] && TEMPMIN="0$TEMPMIN"
		RENAMED="${NEWNAME}_${LITYEAR}_${LITJDAY}_${LITHOUR}_${TEMPMIN}"
		TEMPMIN=$(sed -r -e 's/0([0-9])/\1/' <<< ${TEMPMIN})
		done
		mv $j1 $RENAMED
		echo "Moved $j1 to $RENAMED"
	    fi
 	    ((N++));
	fi
     done
 else # any other number of backups should be handles here, either delete to get down to 3 or add to get up to it.
     echo "unexpected number of backups, get back to three"
     numBackups=${#EXISTBACKS[@]}; echo "Current # of directories: $numBackups"
     numRemove=$(($numBackups-3)); echo "Number of dirs to remove: $numRemove"
     numAdd=0; # ((numRemove--))    
     [[ numRemove -gt 0 ]] && for ((jrm=0; jrm<${numRemove}; jrm++)); do rm -rv ${EXISTBACKS[jrm]}; done
     [[ numRemove -lt 0 ]] && numAdd=$(echo ${numRemove#-}); echo "Number of dirs to add: $numAdd"
    if [[ $numAdd -gt 0 ]]; then
     ORIGMIN=$LITMIN
     for ((j2=0; j2<$numAdd; j2++)); do 
     LITMIN=$( echo $LITMIN | sed -r 's/^0*//')
     # Get rid of leading zeros, if it was only zeros, set back to 0.
     [[ ${#LITMIN} -lt 1 ]] && LITMIN=1
     ((LITMIN--))
     [[ ${#LITMIN} -lt 2 ]] && LITMIN="0$LITMIN"
     echo $N1
     rsync -avz  "${SOURCELOCS[$((N1))]}/" "${j}_${LITYEAR}_${LITJDAY}_${LITHOUR}_${LITMIN}"
     done
     LITMIN=$ORIGMIN
    fi
 fi
((N1++))
[[ N1 -ge ${#SOURCELOCS[@]} ]] && N1=0
done
# set +x

printf %"s\n"
CURTIME=$(date "+%Y %j %H %M")
echo "End of current run at: ${CURTIME}"

#BACKUP my documents folder in home to both external drives.
#if you want something to be backed up, make sure it is in there
#rsync -avz ~/Documents /media/jadesrochers/Seagate_D2/1701A_Docs
#rsync -avz ~/Documents /media/jadesrochers/Seagate_D1/1701A_Docs
# backup my pictures in the ntfs partition to both external drives. work from this picture folder.
# rsync -avz /media/jadesrochers/Data_Store/Filed\ Pictures /media/jadesrochers/Seagate_D2/1701A_Pictures
# rsync -avz /media/jadesrochers/Data_Store/Filed\ Pictures /media/jadesrochers/Seagate_D1/1701A_Pictures
# # backup my music, work from this folder. also on the ntfs data storage partition on the HP.
# rsync -avz /media/jadesrochers/Data_Store/Music /media/jadesrochers/Seagate_D2/1701A_Music
# rsync -avz /media/jadesrochers/Data_Store/Music /media/jadesrochers/Seagate_D1/1701A_Music