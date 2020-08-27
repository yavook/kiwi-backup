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

For effective use of GnuPG encryption, you will need a GnuPG key and a custom image.

For simplicity, this guide assumes you have a `kiwi-scp` instance with some project where you want to put your backup service. You should have a shell opened in that project's directory.

### GnuPG Key Generation

> If you already have a key you want to use for this instance, skip this section.

Reasonable defaults for a backup encryption key are:

* User ID: `Administrator <root@my-hostname.com>`
* 4096 bit RSA
* Doesn't expire
* Secure passphrase (Don't bother memorizing it, you will save it in your `kiwi-scp` instance!)

To quickly generate a key, use the following command, then enter your passphrase:

```sh
docker run --rm -it -v "$(pwd)/gnupg.tmp:/root/.gnupg" ldericher/kiwi-backup gpg --quick-gen-key --yes "Administrator <root@my-hostname.com>" rsa4096 encr never
```

This creates a subdirectory "gnupg.tmp" in the current working directory, which will be discarded later.

To get a more in-depth generation wizard instead, use the following command and follow its directions:

```sh
docker run --rm -it -v "$(pwd)/gnupg.tmp:/root/.gnupg" ldericher/kiwi-backup gpg --full-gen-key
```

### Key-ID

> If you already have a key you want to use for this instance, skip this section.

During key generation, there's an output line `gpg: key 38CD19177F84710B marked as ultimately trusted` where `38CD19177F84710B` will be your Key-ID. If you lost it, you can list the keys using `gpg -k`:

```sh
docker run --rm -v "$(pwd)/gnupg.tmp:/root/.gnupg" ldericher/kiwi-backup gpg -k | grep -A1 '^pub'
```

Output (shortened):

```
[...]
pub   rsa4096 2020-08-27 [SC]
      82BA35B0871675F78165618238CD19177F84710B
```

You can use the full fingerprint `82BA35B0871675F78165618238CD19177F84710B` or abbreviate to the last 16 digits `38CD19177F84710B`. Checking your Key-ID should succeed:

```sh
docker run --rm -v "$(pwd)/gnupg.tmp:/root/.gnupg" ldericher/kiwi-backup gpg --fingerprint 38CD19177F84710B
```

For more possibilities of what counts as a Key-ID, refer to [the relevant GnuPG manual section](https://www.gnupg.org/documentation/manuals/gnupg/Specify-a-User-ID.html)

### Export the key

You now have a key to use for this instance. Export it into a new subdirectory "backup" in your project.

The following one-liner extracts the data from the previously generated "gnupg.tmp" directory:

```sh
docker run --rm -it -v "$(pwd)/gnupg.tmp:/root/.gnupg" -v "$(pwd)/backup:/root/backup" -e "CURRENT_USER=$(id -u):$(id -g)" ldericher/kiwi-backup sh -c 'cd /root/backup && gpg --export-secret-keys --armor > secret.asc && gpg --export-ownertrust > ownertrust.txt && chown -R "${CURRENT_USER}" .'
```

You'll now find the "backup" subdirectory having files "secret.asc" and "ownertrust.txt" in it.

If you did not generate your keys using the container and want to export them manually, use these commands:

```sh
gpg --export-secret-keys --armor [Key-ID] > /path/to/backup/secret.asc
gpg --export-ownertrust > /path/to/backup/ownertrust.txt
```

Optionally, check your export:

```sh
docker run --rm -v "$(pwd)/backup:/root/backup:ro" ldericher/kiwi-backup sh -c 'cd /root/backup && gpg --import --batch secret.asc && gpg --import-ownertrust ownertrust.txt && gpg -k'
```

Output (shortened):

```
[...]
pub   rsa4096 2020-08-27 [SC]
      82BA35B0871675F78165618238CD19177F84710B
uid           [ultimate] Administrator <root@my-hostname.com>
```

### Describe local kiwi-backup image

You now have a "backup" subdirectory containing your key export file and can safely discard a leftover "gnupg.tmp" subdirectory if applicable.

Now create a simple `Dockerfile` inside the "backup" directory from following template.

```Dockerfile
FROM ldericher/kiwi-backup

COPY secret.asc ownertrust.txt /root/

RUN set -ex; \
    \
    gpg --import --batch /root/secret.asc; \
    gpg --import-ownertrust /root/ownertrust.txt; \
    rm /root/secret.asc /root/ownertrust.txt

# Obviously, change these values to match your data!
ENV GPG_KEY_ID="38CD19177F84710B" \
    GPG_PASSPHRASE="changeme"
```

You should add the "backup" directory to the repository backing up your `kiwi-scp` instance.

### Use local image

All that's left to do is come back to your project's `docker-compose.yml`, where you shorten one line. Old:

```yaml
backup:
  image: ldericher/kiwi-backup
  # [...]
```

New:

```yaml
backup:
  build: ./backup
  # [...]
```

That's it! `kiwi-backup` will automatically start encrypting your new backups.

## Offsite Backups

