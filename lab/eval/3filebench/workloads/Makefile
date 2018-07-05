SH=$(wildcard *.sh)
WML=$(SH:%.sh=%.f)
all:$(WML)

%.f:%.sh
	bash $< > $@

clean:
	rm -f $(WML)
