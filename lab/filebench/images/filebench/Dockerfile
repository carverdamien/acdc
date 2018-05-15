FROM gcc
RUN apt-get update
RUN apt-get install -y byacc
WORKDIR /home
COPY ./*.c ./*.h config* install-sh Makefile* missing aclocal.m4 depcomp parser_* ylwrap ./
COPY workloads ./workloads
RUN ./configure
RUN make
RUN make install
CMD filebench
