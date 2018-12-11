PYTHON=$(wildcard *.py)
PDF=$(PYTHON:%.py=%.pdf)

all: $(PDF)
	pdflatex main.tex

%.pdf:%.py
	python $< $@

clean:
	rm -f $(PDF)

# Template Section
CONFIGS=baseline 1mcg 2mcgl 2mcgm
TEMPLATE=$(wildcard .template/*py)
TEMPLATED=$(foreach v,$(CONFIGS),$(foreach t,$(TEMPLATE:.template/%=%),$(v)-$(t)))
template: $(TEMPLATED)
define template-rule
$(1)-%.py:.template/%.py
	ln -sf $$< $$@
endef
$(foreach v,$(CONFIGS),$(eval $(call template-rule,$v)))
cleantemplate:
	rm -f $(TEMPLATED)
