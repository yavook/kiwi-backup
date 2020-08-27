# kiwi-backup

> `kiwi` - simple, consistent, powerful

The backup solution for [`kiwi-scp`](https://github.com/ldericher/kiwi-scp)

## Quick start

Assuming the backups should be kept locally in `/var/kiwi.backup`, just add this to one of your projects' `docker-compose.yml`.

```yaml
backup:
  image: ldericher/kiwi-backup
  volumes:
    - "$TARGETROOT:/backup/source:ro"
    - "/var/kiwi.backup:/backup/target"
```

This will use the default configuration.

- backups the entire service data directory
- stores all backup data on the host file system
- daily incremental backups at night (03:36 am UTC; time chosen by fair dice roll)
- a new full backup once every 4 months
- keeps backups for up to 9 months 
- keeps incremental backups for the most recent chain (4 months)

## Customization

The kiwi-backup image allows for extensive customization even without creating a local image variant.

Schedules in environment variables are to be provided [in cron notation](https://crontab.guru/).

### Backup Scope

kiwi-backup will backup everything in its `/backup/source` directory, and you should have no incentive to change that.

To change the backup scope, just change what's mounted into that container directory:

```yaml
backup:
  # ...
  volumes:
    - "$TARGETROOT:/backup/source:ro" # change me!
```

You may of course create additional sources below in the `/backup/source` directory to limit the backup to specific projects or services. For added safety, mount your backup sources read-only by appending `:ro`.

### Backup policy

These are the environment variables to change the basic backup policy.

```yaml
backup:
  # ...
  environment:
    # ...
    
    # when to run backups
    # default: "36 03 * * *" <=> daily at 03:36 am
    SCHEDULE_BACKUP: "36 03 * * *"
    
    # when to remove failed transactions
    # default: "36 04 * * *" <=> daily at 04:36 am
    SCHEDULE_CLEANUP: "36 04 * * *"
    
    # how often to opt for a full backup
    # default: "4M" <=> every 4 months
    FULL_BACKUP_FREQUENCY: "4M"

    # how long to keep backups at all
    # default: "9M" <=> 9 months
    BACKUP_RETENTION_TIME: "9M"
    
    # how many full backup chains with incrementals to keep
    # default: "1"
    KEEP_NUM_FULL_CHAINS: "1"
    
    # where to put backups
    # default: "file:///backup/target" <=> likely in a host-mounted volume
    BACKUP_TARGET: "file:///backup/target"
```

### Additional options

There's more environment variables for further customization. You'll likely know if you need to change these.

```yaml
backup:
  # ...
  environment:
    # ...

    # when to remove old full backup chains
    # default: "36 05 * * SAT" <=> every saturday at 05:36 am
    SCHEDULE_RMFULL: "36 05 * * SAT"

    # when to remove old incremental backups
    # default: "36 05 * * SUN" <=> every sunday at 05:36 am
    SCHEDULE_RMINCR: "36 05 * * SUN"
    
    # size of individual duplicity data volumes
    # default: "1024" <=> 1GiB
    BACKUP_VOLSIZE: "1024"
    
    # Additional options for "duplicity --full-if-older-than" command
    OPTIONS_BACKUP: ""
    
    # Additional options for "duplicity cleanup" command
    OPTIONS_CLEANUP: ""
    
    # Additional options for "duplicity remove-older-than" command
    OPTIONS_RMFULL: ""
    
    # Additional options for "duplicity remove-all-inc-of-but-n-full" command
    OPTIONS_RMINCR: ""
```

## Encryption

For effective use of GnuPG encryption, you will need a custom `Dockerfile`.

## Offsite Backups

