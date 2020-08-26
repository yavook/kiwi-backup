#!/bin/sh

get_cron_line() {
    task="${1}"
    shift 1

    cmdline='/bin/ionice -c 3 /usr/bin/duplicity --no-encryption'

    case "${task}" in
        backup)
            cmdline="${cmdline} --allow-source-mismatch --volsize 1024 --full-if-older-than ${FULL_BACKUP_FREQUENCY} /backup/source"
            ;;
        
        clean)
            cmdline="${cmdline} cleanup --force"
            ;;
        
        rmfull)
            cmdline="${cmdline} remove-older-than ${BACKUP_RETENTION_TIME} --force"
            ;;
        
        rmincr)
            cmdline="${cmdline} remove-all-inc-of-but-n-full ${KEEP_NUM_FULL_CHAINS} --force"
            ;;
    esac

    cmdline="${cmdline} file:///backup/target"
    echo "${cmdline}"
}

prepare_crontab() {
    echo "${SCHEDULE_BACKUP}"  "$(get_cron_line backup)"
    echo "${SCHEDULE_CLEANUP}" "$(get_cron_line clean)"
    echo "${SCHEDULE_RMFULL}"  "$(get_cron_line rmfull)"
    echo "${SCHEDULE_RMINCR}"  "$(get_cron_line rmincr)"
}

get_crontab() {
    echo   '# crontab generated for kiwi-backup'
    printf '# generation time: '; date
    echo   '#'
    prepare_crontab
}

# replace crontab, start crond
get_crontab | crontab -
crond -fl 8
