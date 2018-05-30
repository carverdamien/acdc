PY=$(wildcard *.py)
PDF=$(PY:%.py=%.pdf)
PNG=$(PY:%.py=%.png)
DAT=$(wildcard */trace.dat)
DATCSV=$(DAT:%.dat=%.csv)

all: $(PDF) $(PNG) $(DATCSV)

%.pdf: %.py
	python $< $@

%.png: %.py
	python $< $@

%.csv: %.dat
	echo 'proc,time,delay,func' > $@
	trace-cmd report -i $< | sed -n 's/ *\([^ ]*\) *[^ ]* \([^ ]*\): [^ ]*: *. \([^ ]* [^ ]*\) | *\([^ ]*\)();/\1,\2,\3,\4/p' | sed 's/ us//g' >> $@

clean:
	rm -f $(PDF) $(PNG)
