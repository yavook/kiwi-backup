#!/bin/sh

#############
# CONSTANTS #
#############

# commands
env_exe="$(command -v env)"
ionice_exe="$(command -v ionice)"
duplicity_exe="$(command -v duplicity)"

# check if uses encryption
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

append_options() {
    ao_cmdline="${1}"
    ao_options="${2}"
    shift 1

    # remove leading whitespace characters
    ao_options="${ao_options#"${ao_options%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    ao_options="${ao_options%"${ao_options##*[![:space:]]}"}"

    # if options are given, stitch together with a space
    if [ -n "${ao_options}" ]; then
        echo "${ao_cmdline} ${ao_options}"
    else
        echo "${ao_cmdline}"
    fi
}

print_command() {
    pc_task="${1}"
    shift 1

    # if environment should be changed, call with "env"
    if [ -n "${env_changes}" ]; then
        pc_cmdline="${env_exe} ${env_changes} "
    else
        pc_cmdline=""
    fi

    pc_cmdline="${pc_cmdline}${ionice_exe} -c 3 ${duplicity_exe} ${encrypt_opts}"

    case "${pc_task}" in
        backup)
            pc_cmdline="${pc_cmdline} --allow-source-mismatch --volsize ${BACKUP_VOLSIZE} --full-if-older-than ${FULL_BACKUP_FREQUENCY}"
            pc_cmdline="$( append_options "${pc_cmdline}" "${OPTIONS_BACKUP} /backup/source" )"
            ;;
        
        cleanup)
            pc_cmdline="${pc_cmdline} cleanup --force"
            pc_cmdline="$( append_options "${pc_cmdline}" "${OPTIONS_CLEAN}" )"
            ;;
        
        rmfull)
            pc_cmdline="${pc_cmdline} remove-older-than ${BACKUP_RETENTION_TIME} --force"
            pc_cmdline="$( append_options "${pc_cmdline}" "${OPTIONS_RMFULL}" )"
            ;;
        
        rmincr)
            pc_cmdline="${pc_cmdline} remove-all-inc-of-but-n-full ${KEEP_NUM_FULL_CHAINS} --force"
            pc_cmdline="$( append_options "${pc_cmdline}" "${OPTIONS_RMINCR}" )"
            ;;
    esac

    pc_cmdline="${pc_cmdline} ${BACKUP_TARGET}"
    echo "${pc_cmdline}"
}

print_cron_schedule() {
    pcs_min="$(     echo "${1}" | awk '{print $1}' )"
    pcs_hour="$(    echo "${1}" | awk '{print $2}' )"
    pcs_day="$(     echo "${1}" | awk '{print $3}' )"
    pcs_month="$(   echo "${1}" | awk '{print $4}' )"
    pcs_weekday="$( echo "${1}" | awk '{print $5}' )"
    pcs_command="${2}"
    shift 2
    
    printf '%-8s%-8s%-8s%-8s%-8s%s\n' "${pcs_min}" "${pcs_hour}" "${pcs_day}" "${pcs_month}" "${pcs_weekday}" "${pcs_command}"
}

print_crontab() {
    echo   '# crontab generated for kiwi-backup'
    printf '# generation time: '; date
    echo   '#'

    # don't split the '#' from 'min'
    print_cron_schedule '#_min hour day month weekday' 'command' | tr '_' ' '

    print_cron_schedule "${SCHEDULE_BACKUP}"  "$( print_command backup )"
    print_cron_schedule "${SCHEDULE_CLEANUP}" "$( print_command cleanup )"
    print_cron_schedule "${SCHEDULE_RMFULL}"  "$( print_command rmfull )"
    print_cron_schedule "${SCHEDULE_RMINCR}"  "$( print_command rmincr )"
}

########
# MAIN #
########


if [ "${#}" -gt 0 ]; then
    # run a command
    case "${1}" in
        print-crontab)
            print_crontab
            ;;

        print-backup|print-cleanup|print-rmfull|print-rmincr)
            print_command "${1##*-}"
            ;;

        # execute single command
        backup|cleanup|rmfull|rmincr)
            print_command "${1}"
            cmd="$(print_command "${1}")"
            ${cmd}
            ;;

        *)
            >&2 echo "Unknown command '${1}'."
            exit 1
            ;;
    esac

else
    # default run: replace crontab, then start crond
    print_crontab | crontab -
    crond -fl 8
fi

exit 0