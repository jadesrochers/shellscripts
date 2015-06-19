#! /bin/bash

exec 1>> $HOME/bin/log/offMachines.log 2>&1
printf %"s\n\n\n\n\n"
# give info about when the run was for the log file
CURTIME=$(date "+%Y %j %H %M")
echo "Start of current run at: ${CURTIME}"
printf %"s\n"

#list of ips and associated mac addresses
# Could automate generating these in another script, but it would need to be run when all machines are active.
declare -a ips=(192.168.2.10{9,7,5})    #{9,7,5,3,1}
declare -a macs=("00:1F:29:9D:B1:59" "00:1F:29:9D:F4:EC" "00:1F:29:9D:54:33" "00:1F:29:9D:F4:E3" "60:eb:69:53:e9:ee")

# Scan for which machines are awake or not
# -c 2 limits to 2 pings, -t 2 waits for two seconds till timing out.
n=0; 
for ip in ${ips[@]}; do ping -c 2 -t 2 $ip > /dev/null; 
if [[ $? -eq 0 ]]; then
echo "$ip was up, shutting it down"
ssh backuponly@$ip -i /home/backuponly/.ssh/backuponly_rsa "sudo shutdown -h now"
# ssh backuponly@$ip 'sudo poweroff' #single quotes to prevent local shell evaluation. And then I realized none of this will work resulting in the marathon to get the backuponly on all the other computers with sudoless permission to shutdown.
else
echo "$ip was off, leaving in that state"
fi
((n++)); 
done

# give info about the end of the run for the log file.
printf %"s\n"
CURTIME=$(date "+%Y %j %H %M")
echo "End of current run at: ${CURTIME}"
