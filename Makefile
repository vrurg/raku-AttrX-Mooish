
MAIN_MOD=lib/AttrX/Mooish.pm6

all: 
	echo "Useful targets: test, readme, release"

readme: $(MAIN_MOD)
	@perl6 --doc=Markdown $(MAIN_MOD) >README.md

test:
	@prove -l --exec "perl6 -Ilib" -r t

author-test:
	@AUTHOR_TESTING=1 prove -l --exec "perl6 -Ilib" -r t

release: author-test
	@git archive --prefix=Vortex-TotalPerspective-0.0.1/ -o ../Vortex-TotalPerspective-0.0.1.tar.gz HEAD
