SRC=$(wildcard *.tex)
TARGET=$(SRC:%.tex=%.pdf)
CLEAN=$(foreach src,$(SRC),$(foreach ext,log aux,$(src:%.tex=%).$(ext)))

all: $(TARGET)

%.pdf:%.tex
	pdflatex $<

clean:
	rm -f $(CLEAN)

cleanall: clean
	rm -f $(TARGET)