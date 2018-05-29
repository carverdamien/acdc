FROM gcc
RUN apt-get update
RUN apt-get install -y byacc flex python-pip
WORKDIR /home
COPY ./*.c ./*.h config* install-sh Makefile* missing aclocal.m4 depcomp parser_* ylwrap ./
COPY workloads ./workloads
RUN ./configure \
&&  make \
&&  make install
COPY requirements.txt ./
RUN pip install -r requirements.txt
COPY benchmark.py ./
ENTRYPOINT [ "sleep", "inf" ]
