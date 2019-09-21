

# charge fV based on the file system
isbatt_charging () {
  local retVal=false
  local chargefV=$(batt_mA)
  if [[ $chargefV -gt 0 ]]; then retVal=true; fi
  printf "%s" "$retVal";
}

# battery raw mV from the file monitoring it
batt_mV () {
  printf "%s" "$(cat /sys/class/hwmon/hwmon1/device/in12_input)"
}

# battery raw mA from the file monitoring it
batt_mA () {
  printf "%s" "$(($(cat /sys/class/hwmon/hwmon1/device/in2_input)-1250))"
}

battery_percent () {
  printf "%s" $(python "/usr/share/IdentEvent/ShellScripts/battery_calculations.py")
}