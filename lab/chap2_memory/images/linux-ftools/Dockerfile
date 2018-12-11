FROM ubuntu
WORKDIR /home
RUN apt-get update \
&& apt-get install -y \
   build-essential
COPY AUTHORS ChangeLog configure configure.ac COPYING debian depcomp INSTALL install-sh linux-fadvise.c linux-fallocate.c linux-fincore.c linux-ftools.h Makefile.am Makefile.in missing NEWS README RELEASE showrlimit.c waste_memory.c ./
RUN ./configure
RUN make install || echo 'FIX: target "missing" fails'
