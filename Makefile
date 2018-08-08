
MAIN_MOD=lib/AttrX/Mooish.pm6
MOD_VER:=$(shell perl6 -Ilib -e 'use AttrX::Mooish; AttrX::Mooish.^ver.say')
MOD_NAME_PFX=AttrX-Mooish
MOD_DISTRO=$(MOD_NAME_PFX)-$(MOD_VER)
MOD_ARCH=$(MOD_DISTRO).tar.gz

CLEAN_FILES=$(MOD_NAME_PFX)-v*.tar.gz
CLEAN_DIRS=lib/.precomp

all: 
	echo "Useful targets: test, readme, release"

readme: $(MAIN_MOD)
	@perl6 --doc=Markdown $(MAIN_MOD) >README.md

test:
	@prove -l --exec "perl6 -Ilib" -r t

author-test:
	@echo "===> Author testing"
	@AUTHOR_TESTING=1 prove -l --exec "perl6 -Ilib" -r t

release-test:
	@echo "===> Release testing"
	@RELEASE_TESTING=1 prove -l --exec "perl6 -Ilib" -r t

release: release-test $(MOD_ARCH)
	@echo "===> Done releasing"

$(MOD_ARCH): Makefile
	@echo "===> Creating release archive" $(MOD_ARCH)
	@git archive --prefix="$(MOD_DISTRO)/" -o $(MOD_ARCH) $(MOD_VER)

upload: release
	@echo "===> Uploading to CPAN"
	@cpan-upload -d Perl6 --md5 $(MOD_ARCH)
	@echo "===> Uploaded."

clean:
	@rm $(CLEAN_FILES)
	@rm -rf $(CLEAN_DIRS)
