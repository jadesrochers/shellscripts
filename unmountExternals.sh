#! /bin/bash
# this script is designed to unmount all external
# file systems without knowing what they are or where 
# they are mounted. Gain this info from console calls.
# This file has the SUID bit set:
# sudo chmod 4711 Documents/ShellScripts/unmountExternals.sh 
# and the owner changed to root:
# sudo chown root Documents/ShellScripts/unmountExternals.sh
# This allows anyone to run it, but it runs with root priv.

# set -x
# get only the lines from the df -a output that are not the a device
EXTERNALS=$(df -a | egrep '/dev/sd[^a]')
# reduce these lines to just the device designation and mountdir
# the rn is extended regex, noprint, gp is global and print
# the regex itself is start word (\<) and match nums and percent.
EXTERNALCUT=$(echo $EXTERNALS | sed -rn 's/\<[0-9%]* //gp')
# extract the device and mount point to variables. loop 
# till all the found devices have been used, then quit.
while [ -n "$EXTERNALCUT" ]; do
# get the device name
DEV=$(echo $EXTERNALCUT | sed -rn 's/ \/.*//pg')
# the path for the drive will have slashes, they need to be escaped.
# this sed command should deal with all possible special chracters
# by escaping them.
SAFEDEV=$(echo $DEV | sed 's/[[\.*^$(){}?+|/]/\\&/g')
# Remove just the part of the external info that has been 
# extracted. Use the safe variable to do this
EXTERNALCUT=$(echo $EXTERNALCUT | sed -rn "s/${SAFEDEV} //p")
# repeat the same steps to get the location the drive is attached.
LOC=$(echo $EXTERNALCUT | sed -rn 's/ \/.*//pg')
SAFELOC=$(echo $LOC | sed 's/[[\.*^$(){}?+|/]/\\&/g')
EXTERNALCUT=$(echo $EXTERNALCUT | sed -rn "s/${SAFELOC} //p")
umount "$DEV" 
done

# set +x