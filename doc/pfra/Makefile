DOT=$(wildcard *.dot)
TEX=$(wildcard *.tex)
TARGET=$(TEX:%.tex=%.pdf) $(DOT:%.dot=%.pdf) 
CLEAN=$(foreach tex,$(TEX),$(foreach ext,log aux,$(tex:%.tex=%).$(ext)))

all: $(TARGET)

%.pdf:%.tex
	pdflatex $<

%.pdf:%.dot
	circo -Tpdf -o$@ $<

clean:
	rm -f $(CLEAN)

cleanall: clean
	rm -f $(TARGET)