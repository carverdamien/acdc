PY=$(wildcard *.py)
PDF=$(PY:%.py=%.pdf)

all: $(PDF)

%.pdf: %.py
	python $< $@

clean:
	rm -f $(PDF)
