default: test
	true

test: all
	cd _build/test/ && ./test.byte $(TESTFLAGS)

.PHONY: test

#+ AUTOBUILD_START 
#+ DO NOT EDIT THIS PART 
#+ tag content_digest "9c4df8fc4855b76c5bf8fabf15fd5ea8" 
#+ tag footer_digest "d41d8cd98f00b204e9800998ecf8427e" 
#+ tag header_digest "d41d8cd98f00b204e9800998ecf8427e" 
# File auto-generated by ocaml-autobuild

BUILD=sh $(CURDIR)/buildsys.sh $(BUILDFLAGS)

# Default target
all:
	$(BUILD) $@

clean:
	$(BUILD) $@

distclean:
	$(BUILD) $@

install:
	$(BUILD) $@

.PHONY: all clean distclean install
#+ AUTOBUILD_STOP 
