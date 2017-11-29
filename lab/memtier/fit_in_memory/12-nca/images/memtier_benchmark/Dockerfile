FROM ubuntu:16.04 as builder
RUN apt-get update
RUN apt-get install -yy build-essential autoconf automake libpcre3-dev libevent-dev pkg-config zlib1g-dev git libboost-all-dev cmake flex
WORKDIR /memtier_benchmark
COPY libmemcached_protocol ./libmemcached_protocol
COPY CHANGES COPYING JSON_handler.cpp JSON_handler.h Makefile.am README.import README.md client.cpp client.h config_types.cpp config_types.h configure.ac file_io.cpp file_io.h item.cpp item.h memtier_benchmark.1 memtier_benchmark.cpp memtier_benchmark.h obj_gen.cpp obj_gen.h protocol.cpp protocol.h ./
RUN autoreconf -ivf && ./configure && make && make install

FROM ubuntu:16.04
LABEL Description="memtier_benchmark"
RUN apt-get update
RUN apt-get install -yy \
    libevent-dev \
    python-pip \
    inotify-tools
COPY --from=builder /usr/local/bin/memtier_benchmark /usr/local/bin/memtier_benchmark
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY benchmark.py .
COPY run /usr/bin/run
COPY job /usr/bin/job
COPY daemon /usr/bin/daemon
ENTRYPOINT [ "daemon" ]
