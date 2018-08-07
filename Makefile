
MAIN_MOD=lib/AttrX/Mooish.pm6
MOD_VER:=$(perl6 -Ilib -e 'use AttrX::Mooish; AttrX::Mooish.^ver.say')
MOD_DISTRO=AttrX-Mooish-$(MOD_VER)

all: 
	echo "Useful targets: test, readme, release"

readme: $(MAIN_MOD)
	@perl6 --doc=Markdown $(MAIN_MOD) >README.md

test:
	@prove -l --exec "perl6 -Ilib" -r t

author-test:
	@AUTHOR_TESTING=1 prove -l --exec "perl6 -Ilib" -r t

release: #author-test
	echo USING MOD_DISTRO $(MOD_DISTRO)
	#git archive --prefix=$(MOD_DISTRO) -o ../$(MOD_DISTRO).tar.gz HEAD
