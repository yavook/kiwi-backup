FROM alpine:3.12
LABEL maintainer="jmm@yavook.de"

# Previous work: https://github.com/wernight/docker-duplicity

RUN set -ex; \
    \
    # create backup source
    mkdir -p /backup/source; \
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

VOLUME ["/root/.cache/duplicity"]

ENV \
    #################
    # BACKUP POLICY #
    #################
    SCHEDULE_BACKUP="36 03 * * *" \
    SCHEDULE_CLEANUP="36 04 * * *" \
    FULL_BACKUP_FREQUENCY=4M \
    BACKUP_RETENTION_TIME=9M \
    KEEP_NUM_FULL_CHAINS=1 \
    BACKUP_TARGET="file:///backup/target" \
    \
    ######################
    # ADDITIONAL OPTIONS #
    ######################
    SCHEDULE_RMFULL="36 05 * * SAT" \
    SCHEDULE_RMINCR="36 05 * * SUN" \
    BACKUP_VOLSIZE=1024 \
    OPTIONS_BACKUP="" \
    OPTIONS_CLEANUP="" \
    OPTIONS_RMFULL="" \
    OPTIONS_RMINCR="" \
    \
    ##############
    # ENCRYPTION #
    ##############
    #
    # GnuPG key-id as specified by https://www.gnupg.org/documentation/manpage.html#sec-2-6
    GPG_KEY_ID="" \
    GPG_PASSPHRASE=""

COPY run.sh /usr/local/bin/do-plicity

CMD ["do-plicity"]
