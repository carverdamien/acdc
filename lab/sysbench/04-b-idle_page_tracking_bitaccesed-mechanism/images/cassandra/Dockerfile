FROM cassandra:latest
RUN apt-get update \
&&  apt-get install -y \
    inotify-tools
COPY start /usr/bin/start
COPY stop /usr/bin/stop
COPY job /usr/bin/job
COPY daemon /usr/bin/daemon
ENTRYPOINT [ "daemon" ]