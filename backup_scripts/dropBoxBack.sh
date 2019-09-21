#!/bin/bash
# This process will run a backup to my dropbox folder every
# half hour until the system shuts down

cleanup () {
    printf %"sFinished up\n"
    # need to exit to break the infinite loop
    exit 0
}

trap cleanup SIGINT SIGQUIT SIGTERM
trap load_config SIGHUP

load_config () {
    source /home/jadesrochers/bin/shellScripts/backup_scripts/dropBoxBack_functions.sh
}

run_continuous () {
    systemd-notify --ready --status="Running backup loop"
    while true; do
	run_backup
        printf "Ran scheduled backup at %s\n" "$(date)"
        sleep 2400s
    done
}

run_once () {
    run_backup
    printf "Ran single backup at %s\n" "$(date)"
    return 0
}

load_config
case "$1" in
    once)
        run_once
    ;;
    continuous)
        run_continuous 
    ;;
    *)
	printf "Option to dropboxback not recognized\n"
	printf "Usage: $0 {once|continuous}\n"
    ;;
esac

