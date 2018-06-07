SH=$(shell find . -name '*.sh')
WML=$(SH:%.sh=%.f)
all:$(WML)

run.f:run.sh prepare.sh

%.f:%.sh
	bash $< > $@

clean:
	rm -f $(WML)
