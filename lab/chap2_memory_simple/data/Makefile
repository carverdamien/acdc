PYTHON=$(wildcard *.py)
PDF=$(PYTHON:%.py=%.pdf)
DAT=$(wildcard */trace.dat)
DATCSV=$(DAT:%.dat=%.csv)

all: $(PDF)
	pdflatex main.tex

$(PDF):$(DATCSV)

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

# trace-cmd Section
%.csv: %.dat
	echo 'proc,time,delay,func' > $@
	trace-cmd report -i $< | sed -n 's/ *\([^ ]*\) *[^ ]* \([^ ]*\): [^ ]*: *. \([^ ]* [^ ]*\) | *\([^ ]*\)();/\1,\2,\3,\4/p' | sed 's/ us//g' >> $@
