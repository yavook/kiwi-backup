# kiwi-backup

[![Build Status](https://github.drone.yavook.de/api/badges/yavook/kiwi-backup/status.svg)](https://github.drone.yavook.de/yavook/kiwi-backup)

> `kiwi` - simple, consistent, powerful

The backup solution for [`kiwi-scp`](https://github.com/yavook/kiwi-scp). Also [on Docker Hub](https://hub.docker.com/r/yavook/kiwi-backup).

## Quick start

kiwi-backup is an image with [duplicity](https://duplicity.gitlab.io/duplicity-web/), tailored to backup service data of `kiwi-scp` instances.

If you want backups in the host directory `/var/local/kiwi.backup`, just add this to one of your projects' `docker-compose.yml` to use the default configuration.

```yaml
backup:
  image: yavook/kiwi-backup:0.10
  volumes:
    - "${KIWI_INSTANCE}:/kiwi-backup/source:ro"
    - "/var/local/kiwi.backup:/kiwi-backup/target"
```

- backups the entire service data directory
- stores all backup data on the host file system
- daily incremental backups at night 
- a new full backup once every 3 months
- keeps backups up to 6 months old
- keeps daily backups for two recent sets (3-6 months)
- backup jobs run at a random minute past 2 am

Be aware though -- backups will use a fair bit of storage space!

## Customization

The kiwi-backup image allows for extensive customization even without creating a local image variant.

Schedules in environment variables are to be provided [in cron notation](https://crontab.guru/). Additionally, the special value "R" is supported and will be replaced by a random value.

### Time Zones

Being based on [`kiwi-cron`](https://github.com/yavook/kiwi-cron), `kiwi-backup` makes changing time zones easy. Just change the container environment variable `TZ` to your liking, e.g. "Europe/Berlin".

### Backup Scope

kiwi-backup will backup everything in its `/kiwi-backup/source` directory -- change the backup scope by adjusting what's mounted into that container directory.

```yaml
backup:
  # ...
  volumes:
    # change scope here!
    - "${KIWI_INSTANCE}:/kiwi-backup/source:ro"
```

You may of course create additional sources below the `/kiwi-backup/source` directory to limit the backup to specific projects or services. For added safety, mount your backup source(s) read-only by appending `:ro`.

You may also change the container environment variable `BACKUP_SOURCE`, though this is discouraged.

### Backup policy

These are the environment variables to change the basic backup policy.

```yaml
backup:
  # ...
  environment:
    # ...

    # when to run backups
    # default: daily at a random minute past 2 am
    SCHEDULE_BACKUP: "R 2 * * *"
    
    # when to remove leftovers from failed transactions
    # default: daily at a random minute past 4 am
    SCHEDULE_CLEANUP: "R 4 * * *"
    
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

### Handling Secrets

`duplicity` usually handles secrets by [reading its environment](http://duplicity.nongnu.org/vers7/duplicity.1.html#sect6). Some of its backends also accept secrets via environment, [notably the AWS S3 backend](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html). 

There are three major ways to for inject secrets into `kiwi-backup` environments:

#### Container environment

Just fire up your container using `docker run -e "FTP_PASSWORD=my_secret_here" yavook/kiwi-backup:0.10`

#### Image environment

Create a simple `Dockerfile` from following template.

```Dockerfile
FROM yavook/kiwi-backup:0.10
ENV FTP_PASSWORD="my_secret_here"
```

#### "Secrets" file in container

Create a shell script:

```sh
#!/bin/sh

export FTP_PASSWORD="my_secret_here"
```

Then, include that file as `/root/duplicity_secrets` into your container by building a custom `Dockerfile` or by mounting it as a (read-only) volume.

### Additional options

There's more environment variables for further customization. You'll likely know if you need to change these.

```yaml
backup:
  # ...
  environment:
    # ...

    # when to remove old full backup chains
    # default: every Saturday at a random minute past 5 am
    SCHEDULE_RMFULL: "R 5 * * SAT"

    # when to remove old incremental backups
    # default: every Sunday at a random minute past 5 am
    SCHEDULE_RMINCR: "R 5 * * SUN"
    
    # size of individual duplicity data volumes
    # default: 1GiB
    BACKUP_VOLSIZE: "1024"
    
    # what to base backups on
    # default: container directory "/kiwi-backup/source", usually mounted volume(s)
    BACKUP_SOURCE: "/kiwi-backup/source"
    
    # where to put backups
    # default: container directory "/kiwi-backup/target", usually a mounted volume
    BACKUP_TARGET: "file:///kiwi-backup/target"
    
    # Additional options for all "duplicity" commands
    OPTIONS_ALL: ""
    
    # Additional options for "duplicity --full-if-older-than" command
    OPTIONS_BACKUP: ""
    
    # Additional options for "duplicity cleanup" command
    OPTIONS_CLEANUP: ""
    
    # Additional options for "duplicity remove-older-than" command
    OPTIONS_RMFULL: ""
    
    # Additional options for "duplicity remove-all-inc-of-but-n-full" command
    OPTIONS_RMINCR: ""

    # Webhook to be pinged on action (use "%%MSG%%" as a placeholder for a message)
    WEBHOOK_URL: ""

    # Allow self-signed certificates on webhook target
    WEBHOOK_INSECURE: "0"
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
docker run --rm -it -v "kiwi-backup.gnupg.tmp:/root/.gnupg" yavook/kiwi-backup:0.10 gpg --quick-gen-key --yes "Administrator <root@my-hostname.com>" rsa4096 encr never
```

To get a more in-depth generation wizard instead, use `gpg --full-gen-key` command without any more args and follow through.

### Export the generated key

This one-liner exports your generated key into a new subdirectory "kiwi-backup.gnupg":

```sh
docker run --rm -it -v "kiwi-backup.gnupg.tmp:/root/.gnupg" -v "$(pwd)/kiwi-backup.gnupg:/root/kiwi-backup.gnupg" -e "CURRENT_USER=$(id -u):$(id -g)" yavook/kiwi-backup:0.10 sh -c 'cd /root/kiwi-backup.gnupg && gpg --export-secret-keys --armor > secret.asc && gpg --export-ownertrust > ownertrust.txt && chown -R "${CURRENT_USER}" .'
```

You'll now find the "kiwi-backup.gnupg" subdirectory with files "secret.asc" and "ownertrust.txt" in it. Check your exported files:

```sh
docker run --rm -v "$(pwd)/kiwi-backup.gnupg:/root/kiwi-backup.gnupg:ro" yavook/kiwi-backup:0.10 sh -c 'cd /root/kiwi-backup.gnupg && gpg --import --batch secret.asc 2>/dev/null && gpg --import-ownertrust ownertrust.txt 2>/dev/null && gpg -k 2>/dev/null | grep -A1 "^pub" | xargs | tail -c17'
```

This should output your 16-digit Key-ID, so take note of it if you haven't already! Afterwards, run `docker volume rm kiwi-backup.gnupg.tmp` to get rid of the key generation volume.

### Using a pre-generated key

To use a pre-generated key, you'll need to export it manually instead. These are the commands:

```sh
gpg --export-secret-keys --armor [Key-ID] > backup/secret.asc
gpg --export-ownertrust > backup/ownertrust.txt
```

You can still check your exported files :)

```sh
docker run --rm -v "$(pwd)/kiwi-backup.gnupg:/root/kiwi-backup.gnupg:ro" yavook/kiwi-backup:0.10 sh -c 'cd /root/kiwi-backup.gnupg && gpg --import --batch secret.asc && gpg --import-ownertrust ownertrust.txt && gpg -k'
```

### Describe local kiwi-backup image

Now create a simple `Dockerfile` inside the "backup" directory from following template.

```Dockerfile
FROM yavook/kiwi-backup:0.10

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
  image: yavook/kiwi-backup:0.10
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

TODO
