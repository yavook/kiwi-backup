#!/bin/sh

#############
# CONSTANTS #
#############

env_exe="$(command -v env)"
ionice_exe="$(command -v ionice)"
duplicity_exe="$(command -v duplicity)"

if [ -n "${GPG_KEY_ID}" ]; then
    # gpg key given
    env_changes="PASSPHRASE='${GPG_PASSPHRASE}'"
    encrypt_opts="--encrypt-key='${GPG_KEY_ID}'"
else
    # no key given
    env_changes=""
    encrypt_opts="--no-encryption"
fi

#############
# FUNCTIONS #
#############

trim_options() {
    # if args are given, trim whitespace, then add a space in front
    if [ -n "${1}" ]; then
        echo " $( echo "${1}" | xargs )"
    fi
}

print_command() {
    task="${1}"
    shift 1

    if [ -n "${env_changes}" ]; then
        # should change environment
        cmdline="${env_exe} ${env_changes} "
    else
        cmdline=""
    fi

    cmdline="${cmdline}${ionice_exe} -c 3 ${duplicity_exe} ${encrypt_opts}"

    case "${task}" in
        backup)
            cmdline="${cmdline} --allow-source-mismatch --volsize '${BACKUP_VOLSIZE}' --full-if-older-than '${FULL_BACKUP_FREQUENCY}'"
            cmdline="${cmdline}$( trim_options "${OPTIONS_BACKUP}" )"
            cmdline="${cmdline} /backup/source"
            ;;
        
        cleanup)
            cmdline="${cmdline} cleanup --force"
            cmdline="${cmdline}$( trim_options "${OPTIONS_CLEAN}" )"
            ;;
        
        rmfull)
            cmdline="${cmdline} remove-older-than '${BACKUP_RETENTION_TIME}' --force"
            cmdline="${cmdline}$( trim_options "${OPTIONS_RMFULL}" )"
            ;;
        
        rmincr)
            cmdline="${cmdline} remove-all-inc-of-but-n-full '${KEEP_NUM_FULL_CHAINS}' --force"
            cmdline="${cmdline}$( trim_options "${OPTIONS_RMINCR}" )"
            ;;
    esac

    cmdline="${cmdline} '${BACKUP_TARGET}'"
    echo "${cmdline}"
}

print_cron_schedule() {
    min="$(     echo "${1}" | cut -d' ' -f1 )"
    hour="$(    echo "${1}" | cut -d' ' -f2 )"
    day="$(     echo "${1}" | cut -d' ' -f3 )"
    month="$(   echo "${1}" | cut -d' ' -f4 )"
    weekday="$( echo "${1}" | cut -d' ' -f5 )"
    command="${2}"
    
    printf '%-8s%-8s%-8s%-8s%-8s%s' "${min}" "${hour}" "${day}" "${month}" "${weekday}" "${command}"
}

print_cron_header() {
    # don't split the '#' from 'min'
    print_cron_schedule '#_min hour day month weekday' 'command' | tr '_' ' '
}

print_crontab() {
    echo   '# crontab generated for kiwi-backup'
    printf '# generation time: '; date
    echo   '#'
    echo   "$( print_cron_header )"
    echo   "$( print_cron_schedule "${SCHEDULE_BACKUP}"  "$( print_command backup )" )"
    echo   "$( print_cron_schedule "${SCHEDULE_CLEANUP}" "$( print_command cleanup )" )"
    echo   "$( print_cron_schedule "${SCHEDULE_RMFULL}"  "$( print_command rmfull )" )"
    echo   "$( print_cron_schedule "${SCHEDULE_RMINCR}"  "$( print_command rmincr )" )"
}

########
# MAIN #
########

if [ "${1}" = '-n' ]; then
    # dry-run
    print_crontab
    exit 0
fi

# replace crontab, start crond
print_crontab | crontab -
crond -fl 8
exit 0
