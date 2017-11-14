FROM gcc
RUN apt-get update \
&&  apt-get install -y \
    bc
WORKDIR kernelcompile
RUN git clone https://github.com/torvalds/linux
