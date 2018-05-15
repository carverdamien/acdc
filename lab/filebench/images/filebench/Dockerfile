FROM gcc
RUN apt-get update
RUN apt-get install -y byacc flex
WORKDIR /home
COPY ./*.c ./*.h config* Makefile.am parser_* NEWS README AUTHORS ChangeLog COPYING ./
COPY workloads ./workloads
COPY cvars cvars
RUN libtoolize \
&&  aclocal \
&&  autoheader\
&&  automake --add-missing\
&&  autoconf
RUN ./configure \
&&  make \
&&  make install
ENTRYPOINT [ "sleep", "inf" ]
