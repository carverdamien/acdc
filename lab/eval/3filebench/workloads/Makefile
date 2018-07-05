RUN_SH=$(shell find . -name 'run.sh')
PREPARE_SH=$(shell find . -name 'prepare.sh')
SH=$(RUN_SH) $(PREPARE_SH)
RUN_WML=$(RUN_SH:%.sh=%.f)
WML=$(SH:%.sh=%.f)
all:$(WML)

define func
$1:$(1:%run.f=%run.sh) $(1:%run.f=%prepare.sh)
endef

$(foreach e,$(RUN_WML),$(eval $(call func,$(e))))

%.f:%.sh
	bash $< > $@

clean:
	rm -f $(WML)
