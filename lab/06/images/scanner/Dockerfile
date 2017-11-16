FROM ubuntu
RUN apt-get update \
&&  apt-get install -y \
    inotify-tools
WORKDIR scanner
COPY daemon /usr/bin/daemon
COPY scan /usr/bin/scan
COPY job /usr/bin/job
COPY prioritysetter /usr/bin/prioritysetter
ENTRYPOINT [ "daemon" ]
