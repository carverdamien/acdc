FROM python
RUN apt-get update \
&&  apt-get install -y \
    inotify-tools
WORKDIR scanner
COPY daemon /usr/bin/daemon
COPY scan /usr/bin/scan
COPY job /usr/bin/job
COPY softlimitsetter /usr/bin/softlimitsetter
COPY reclaimordersetter /usr/bin/reclaimordersetter
ENTRYPOINT [ "daemon" ]
