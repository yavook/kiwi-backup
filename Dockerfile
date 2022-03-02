FROM yavook/kiwi-cron:0.1
LABEL maintainer="jmm@yavook.de"

COPY requirements.txt /tmp/

RUN set -ex; \
    \
    # duplicity software dependencies
    apk --no-cache add \
        ca-certificates \
        gettext \
        gnupg \
        lftp \
        libffi \
        librsync \
        libxml2 \
        libxslt \
        openssh-client \
        openssl \
        python3 \
        rsync \
    ; \
    update-ca-certificates; \
    \
    # python packages buildtime dependencies
    apk --no-cache add --virtual .build-deps \
        gcc \
        git \
        libffi-dev \
        librsync-dev \
        libxml2-dev \
        libxslt-dev \
        make \
        musl-dev \
        openssl-dev \
        python3-dev \
        py3-pip \
        cargo \
    ; \
    # make use of prebuilt wheels where possible
    python3 -m pip --no-cache-dir \
        install wheel \
    ; \
    \
    # install duplicity
    python3 -m pip --no-cache-dir \
        install -r /tmp/requirements.txt \
    ; \
    python3 -m pip --no-cache-dir \
        install duplicity \
    ; \
    \
    # remove buildtime dependencies
    python3 -m pip --no-cache-dir \
        uninstall -y wheel \
    ; \
    apk del --purge .build-deps; \
    rm -f "/tmp/requirements.txt"; \
    rm -rf "${HOME}/.cargo";

RUN set -ex; \
    \
    # create /kiwi-backup directories tree
    mkdir -m 777 /kiwi-backup; \
    mkdir -m 777 /kiwi-backup/source; \
    mkdir -m 777 /kiwi-backup/target; \
    \
    # create a non-root user
    adduser -D -u 1368 kiwi-backup;

USER kiwi-backup

RUN set -ex; \
    \
    mkdir -p "${HOME}/.cache/duplicity"; \
    mkdir -pm 700 "${HOME}/.gnupg"; \
    \
    # confirm duplicity is working
    duplicity --version;

VOLUME [ "/home/kiwi-backup/.cache/duplicity" ]

ENV \
    #################
    # BACKUP POLICY #
    #################
    SCHEDULE_BACKUP="36 02 * * *" \
    SCHEDULE_CLEANUP="36 04 * * *" \
    FULL_BACKUP_FREQUENCY=3M \
    BACKUP_RETENTION_TIME=6M \
    KEEP_NUM_FULL_CHAINS=2 \
    \
    ######################
    # ADDITIONAL OPTIONS #
    ######################
    SCHEDULE_RMFULL="36 05 * * SAT" \
    SCHEDULE_RMINCR="36 05 * * SUN" \
    BACKUP_VOLSIZE=1024 \
    BACKUP_SOURCE="/kiwi-backup/source" \
    BACKUP_TARGET="file:///kiwi-backup/target" \
    OPTIONS_ALL="" \
    OPTIONS_BACKUP="" \
    OPTIONS_CLEANUP="" \
    OPTIONS_RMFULL="" \
    OPTIONS_RMINCR="" \
    \
    ##############
    # ENCRYPTION #
    ##############
    GPG_KEY_ID="" \
    GPG_PASSPHRASE=""

COPY bin /usr/local/bin/
COPY libexec /usr/local/libexec/

CMD [ "kiwi-backup" ]
