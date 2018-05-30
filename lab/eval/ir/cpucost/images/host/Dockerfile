FROM ubuntu
RUN apt-get update \
&&  apt-get install -y \
    inotify-tools \
    trace-cmd
COPY daemon /usr/bin/daemon
COPY job /usr/bin/job
ENTRYPOINT [ "daemon" ]
