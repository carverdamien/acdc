FROM gcc as linuxsrc
RUN apt-get update \
&&  apt-get install -y \
    bc
WORKDIR kernelcompile
RUN git clone https://github.com/torvalds/linux

FROM linuxsrc
ENV CHECKOUT v4.6
COPY patch.txt linux/patch.txt
RUN cd linux \
&&  git checkout ${CHECKOUT} \
&&  git patch patch.txt
COPY kconfig linux/.config
COPY entrypoint.sh entrypoint.sh
ENTRYPOINT [ "./entrypoint.sh" ]
