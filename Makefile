
MAIN_MOD=AttrX::Mooish
META_MOD=$(MAIN_MOD)
NO_META6=yes
README_SRC = doc-src/AttrX/Mooish.rakudoc
DOC_DIR = doc-src
PROVE_FLAGS?=-I. -It/lib -j$(TEST_JOBS)
CUSTOMIZABLE_TESTS:=$(addsuffix .custom.rakutest,$(basename $(shell grep -l '^#?mooish-custom\s*$$' t/*.rakutest)))

%.custom.rakutest: %.rakutest Makefile build-tools/makefile.inc
	@echo "===> " $< "->" $@
	$(NOECHO)raku -p -e 's/^ "#?mooish-custom" \s* $$/use CustomHOW;/' $< > $@ || rm $@

customize-tests: $(CUSTOMIZABLE_TESTS)

test:: customize-tests

include ./build-tools/makefile.inc
