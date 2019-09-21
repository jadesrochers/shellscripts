#!/bin/bash
# Functions for making determinations about disk devices

# get the name of the disk; it will vary depending on the SD card used.
diskPath () {
  path=$(cat /proc/mounts | grep  --extended-regexp --regex='(vfat|fmask=0022|remount-ro)' | awk '{ printf "%s",$2 }')
  printf "%s" $path
}

diskName () {
  name="$(diskPath)"
  name=${name##*/}
  printf "%s" $name
}

# determine if a disk exists. If so, returns /proc/mounts content, otherwise false.
diskExists () {
  local retVal=false
  local diskStats="$(diskPath)"
  if [[ ! -z "$diskStats" ]]; then retVal=true; fi
  
  printf "%s" "$retVal";
}

# disk size as determined by blockdev. Returns in MB.
diskSize () {
  local diskSizeMB=false
  devName="$(diskName)"
  if [[ ! -z "$devName" ]]; then
    diskSizeMB=$(df -HBM "$(diskPath)" |  awk 'NR==2 {printf "%s", gensub(/[A-Z]+/,"","g",$2)}')
    # diskSizeMB=$(($(blockdev --getsize64 "/dev/${devName}")/1048576))
    # local diskBytes1=$(fdisk -l 2>/dev/null | grep -i "$devName" | sed -r -n 's/.*[[:space:]]([0-9]+)[[:space:]]bytes/\1/p')
    # local diskSize1MB=$(($diskBytes1/1048576))
    # local diskSize2MB=$(($(cat "/sys/block/${devName}/size")*512/1048576))
  fi
  printf "%s" "$diskSizeMB";
}

# Determines disk usage as a percent of total available.
diskUsed () {
  local retVal=false
  local usedSpaceMB availSpaceMB usedPercent mntLocation

  mntExist="$(diskExists)" 
  if [[ "$mntExist"==true ]]; then mntLocation=$(diskPath);  fi
  
  if [[ ! -z "$mntLocation" ]]; then
    usedSpaceMB=$(du -sb "$mntLocation" | awk '{printf "%d", ($1/1048576)}')
    availSpaceMB=$(diskSize)
    if [[ usedSpaceMB ]]; then 
      retVal="$(awk -v avail="$availSpaceMB" -v used="$usedSpaceMB" 'BEGIN{ printf "%3.1f\n", (used/avail)*100}')"
    fi
  fi
  printf "%s" "$retVal";
}

fileSize () {
  local file="$1"
  local sizeMB=$(du -sb "$file" | awk '{printf "%d", ($1/1048576)}')
  printf "%d" "$sizeMB"
}

diskMBFree () {
  mntExist="$(diskExists)" 
  if [[ "$mntExist"==true ]]; then mntLocation=$(diskPath);
    usedSpaceMBdu=$(du -sb "$mntLocation" | awk '{printf "%d", ($1/1048576)}')
    usedSpaceMBdf=$(df -hBM "$mntLocation" |  awk 'NR==2 {printf "%s", gensub(/[A-Z]+/,"","g",$3)}')
    availSpaceMB=$(diskSize)
    if [[ $usedSpaceMBdu -gt $usedSpaceMBdf ]]; then
      openSpaceMB=$(($availSpaceMB - $usedSpaceMBdu))
    else
      openSpaceMB=$(($availSpaceMB - $usedSpaceMBdf))
    fi
  else
    openSpaceMB=0;
  fi
  printf "%d" "$openSpaceMB"
}
