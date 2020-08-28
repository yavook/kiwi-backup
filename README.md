# kiwi-backup

> `kiwi` - simple, consistent, powerful

The backup solution for [`kiwi-scp`](https://github.com/ldericher/kiwi-scp)

## Quick start

kiwi-backup is an image with [duplicity](http://duplicity.nongnu.org/), tailored to backup service data of `kiwi-scp` instances.

If you want backups in the host directory `/var/kiwi.backup`, just add this to one of your projects' `docker-compose.yml` to use the default configuration.

```yaml
backup:
  image: ldericher/kiwi-backup
  volumes:
    - "$TARGETROOT:/backup/source:ro"
    - "/var/kiwi.backup:/backup/target"
```

- backups the entire service data directory
- stores all backup data on the host file system
- daily incremental backups at night 
- a new full backup once every 3 months
- keeps backups up to 6 months old
- keeps daily backups for two recent sets (3-6 months)
- backup jobs run at 02:36 am UTC (time chosen by fair dice roll)

Be aware though -- backups will use a fair bit of storage space!

## Customization

The kiwi-backup image allows for extensive customization even without creating a local image variant.

Schedules in environment variables are to be provided [in cron notation](https://crontab.guru/).

### Backup Scope

kiwi-backup will backup everything in its `/backup/source` directory -- change the backup scope by adjusting what's mounted into that container directory.

```yaml
backup:
  # ...
  volumes:
    # change scope here!
    - "$TARGETROOT:/backup/source:ro"
```

You may of course create additional sources below the `/backup/source` directory to limit the backup to specific projects or services. For added safety, mount your backup sources read-only by appending `:ro`.

### Backup policy

These are the environment variables to change the basic backup policy.

```yaml
backup:
  # ...
  environment:
    # ...

    # when to run backups
    # default: daily at 02:36 am UTC
    SCHEDULE_BACKUP: "36 02 * * *"
    
    # when to remove leftovers from failed transactions
    # default: daily at 04:36 am UTC
    SCHEDULE_CLEANUP: "36 04 * * *"
    
    # how often to opt for a full backup
    # default: every 3 months
    FULL_BACKUP_FREQUENCY: "3M"

    # how long to keep backups at all
    # default: 6 months
    BACKUP_RETENTION_TIME: "6M"
    
    # how many full backup chains with incrementals to keep
    # default: 2
    KEEP_NUM_FULL_CHAINS: "2"
```

### Additional options

There's more environment variables for further customization. You'll likely know if you need to change these.

```yaml
backup:
  # ...
  environment:
    # ...

    # when to remove old full backup chains
    # default: every saturday at 05:36 am UTC
    SCHEDULE_RMFULL: "36 05 * * SAT"

    # when to remove old incremental backups
    # default: every sunday at 05:36 am UTC
    SCHEDULE_RMINCR: "36 05 * * SUN"
    
    # size of individual duplicity data volumes
    # default: 1GiB
    BACKUP_VOLSIZE: "1024"
    
    # where to put backups
    # default: some docker volume
    BACKUP_TARGET: "file:///backup/target"
    
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

For effective use of GnuPG encryption, you will need a GnuPG key and a custom image.

For simplicity, this guide assumes you have a `kiwi-scp` instance with some project where you want to put your backup service. You should have a shell opened in that project's directory.

### GnuPG Key Generation

> You'll usually want to generate a new key for each `kiwi-scp` instance.
> If you have reasons not to, skip this section.

Reasonable defaults for a backup encryption key are:

* User ID: `Administrator <root@my-hostname.com>`
* 4096 bit RSA
* Doesn't expire
* Secure passphrase (Don't bother memorizing it, you will save it in your `kiwi-scp` instance!)

To quickly generate a key, use the following command, then enter a passphrase:

```sh
docker run --rm -it -v "gnupg.tmp:/root/.gnupg" ldericher/kiwi-backup gpg --quick-gen-key --yes "Administrator <root@my-hostname.com>" rsa4096 encr never
```

To get a more in-depth generation wizard instead, use `gpg --full-gen-key` command without any more args and follow through.

### Export the generated key

This one-liner exports your generated key into a new subdirectory "backup":

```sh
docker run --rm -it -v "gnupg.tmp:/root/.gnupg" -v "$(pwd)/backup:/root/backup" -e "CURRENT_USER=$(id -u):$(id -g)" ldericher/kiwi-backup sh -c 'cd /root/backup && gpg --export-secret-keys --armor > secret.asc && gpg --export-ownertrust > ownertrust.txt && chown -R "${CURRENT_USER}" .'
```

You'll now find the "backup" subdirectory with files "secret.asc" and "ownertrust.txt" in it. Check your exported files:

```sh
docker run --rm -v "$(pwd)/backup:/root/backup:ro" ldericher/kiwi-backup sh -c 'cd /root/backup && gpg --import --batch secret.asc 2>/dev/null && gpg --import-ownertrust ownertrust.txt 2>/dev/null && gpg -k 2>/dev/null | grep -A1 "^pub" | xargs | tail -c17'
```

This should output your 16-digit Key-ID, so take note of it if you haven't already! Afterwards, run `docker volume rm gnupg.tmp` to get rid of the key generation volume.

### Using a pre-generated key

To use a pre-generated key, you'll need to export it manually instead. These are the commands:

```sh
gpg --export-secret-keys --armor [Key-ID] > backup/secret.asc
gpg --export-ownertrust > backup/ownertrust.txt
```

You can still check your exported files :)

```sh
docker run --rm -v "$(pwd)/backup:/root/backup:ro" ldericher/kiwi-backup sh -c 'cd /root/backup && gpg --import --batch secret.asc && gpg --import-ownertrust ownertrust.txt && gpg -k'
```

### Describe local kiwi-backup image

Now create a simple `Dockerfile` inside the "backup" directory from following template.

```Dockerfile
FROM ldericher/kiwi-backup

COPY secret.asc ownertrust.txt /root/

RUN gpg --import --batch /root/secret.asc; \
    gpg --import-ownertrust /root/ownertrust.txt; \
    rm /root/secret.asc /root/ownertrust.txt

# fill in these values to match your data
ENV GPG_KEY_ID="changeme" \
    GPG_PASSPHRASE="changeme"
```

If applicable, commit the "backup" directory into the `kiwi-scp` instance repository.

### Use local image

All that's left is to come back to your project's `docker-compose.yml`, where you shorten one line. Change:

```yaml
backup:
  image: ldericher/kiwi-backup
  # ...
```

Into:

```yaml
backup:
  build: ./backup
  # ...
```

That's it -- from now on, all new backups will be encrypted!

## Offsite Backups

