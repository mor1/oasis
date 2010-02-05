default: test

test: all
	cd '$(CURDIR)/test' && ../_build/test/test.byte $(TESTFLAGS)

.PHONY: test

# Default target
all:
	ocamlbuild -tag debug -classic-display oasis.otarget
	cp _build/src/Main.byte _build/src/OASIS.byte

clean:
	-ocamlbuild -classic-display -clean

wc:
	find src/ -name "*.ml" | xargs wc -l
