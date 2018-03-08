FROM gcc as linuxsrc
RUN apt-get update \
&&  apt-get install -y \
    bc
WORKDIR kernelcompile
RUN git clone https://github.com/torvalds/linux

FROM linuxsrc
ENV CHECKOUT v4.6
RUN cd linux \
&&  git checkout ${CHECKOUT}
COPY kconfig linux/.config
COPY entrypoint.sh entrypoint.sh
ENTRYPOINT [ "./entrypoint.sh" ]
