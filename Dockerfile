FROM alpine:3.12
LABEL maintainer="jmm@yavook.de"

# Previous work: https://github.com/wernight/docker-duplicity

ENV \
    #################
    # BACKUP POLICY #
    #################
    #
    # when to run backups
    # default: "36 03 * * *  " <=> daily at 3:36 am
    SCHEDULE_BACKUP="36 03 * * *  " \
    #
    # when to remove failed transactions
    # default: "36 04 * * *  " <=> daily at 04:36 am
    SCHEDULE_CLEANUP="36 04 * * *  " \
    #
    # how often to opt for a full backup
    # default: 4M <=> every 4 months
    FULL_BACKUP_FREQUENCY=4M \
    #
    # how long to keep backups at all
    # default: 9M <=> 9 months
    BACKUP_RETENTION_TIME=9M \
    #
    # how many full backup chains with incrementals to keep
    # default: 1
    KEEP_NUM_FULL_CHAINS=1 \
    \
    ##################
    # CRON SCHEDULES #
    ##################
    #
    # when to remove old full backup chains
    # default: "36 05 * * SAT" <=> every saturday at 05:36 am
    SCHEDULE_RMFULL="36 05 * * SAT" \
    #
    # when to remove old incremental backups
    # default: "36 05 * * SUN" <=> every sunday at 05:36 am
    SCHEDULE_RMINCR="36 05 * * SUN"
    

RUN set -ex; \
    \
    apk add --no-cache \
        ca-certificates \
        gettext \
        gnupg \
        lftp \
        libffi \
        librsync \
        libxml2 \
        libxslt \
        openssh \
        openssl \
        python3 \
        py3-pip \
        py3-six \
        rsync \
    ; \
    update-ca-certificates; \
    \
    # dependencies to build python packages
    apk add --no-cache -t .build-deps \
        gcc \
        libffi-dev \
        librsync-dev \
        libxml2-dev \
        libxslt-dev \
        make \
        musl-dev \
        openssl-dev \
        python3-dev \
    ; \
    \
    # make use of "wheel" python packages
    pip3 install wheel ; \
    \
    pip3 install \
        # main app
        duplicity \
        \
        # general duplicity requirements, based on
        # http://duplicity.nongnu.org/vers8/README
        # https://git.launchpad.net/duplicity/tree/requirements.txt
        fasteners \
        future \
        mock \
        paramiko \
        python-gettext \
        requests \
        urllib3 \
        \
        # backend requirements
        azure-mgmt-storage \
        b2sdk \
        boto \
        boto3 \
        dropbox \
        gdata \
        jottalib \
        mediafire \
        mega.py \
        pydrive \
        pyrax \
        python-swiftclient \
        requests_oauthlib \
    ; \
    \
    # remove buildtime dependencies
    pip3 uninstall -y wheel; \
    apk del --purge .build-deps

COPY run.sh /usr/local/bin/do-plicity

VOLUME ["/backup/source", "/backup/target", "/root/.cache/duplicity", "/root/.gnupg"]

CMD ["do-plicity"]
