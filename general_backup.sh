#!/bin/bash
# This process will run a backup to my dropbox folder every
# so often until the system shuts down

cleanup () {
    printf %"sFinished up\n"
    # need to exit to break the infinite loop
    exit 0
}

trap cleanup SIGINT SIGQUIT SIGTERM
trap load_config SIGHUP

load_config () {
    source /usr/local/bin/general_backup_fcns.sh
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

