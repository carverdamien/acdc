PY=$(wildcard *.py)
PDF=$(PY:%.py=%.pdf)
PNG=$(PY:%.py=%.png)

all: $(PDF) $(PNG)

%.pdf: %.py
	python $< $@

%.png: %.py
	python $< $@

clean:
	rm -f $(PDF)
