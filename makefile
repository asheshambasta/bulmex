OPTIMIZATION=-O0
build: update-cabal
	cabal new-build all -j --ghc-options $(OPTIMIZATION)

file-watch:
	scripts/watch.sh

update-cabal:
	hpack ./bulmex

EXTRA=""
enter:
	nix-shell --cores 0 -j 8 $(EXTRA)

run: create-db
	./dist-newstyle/build/x86_64-linux/ghc-8.4.3/backend-1.0.0.0/x/webservice/build/webservice/webservice

clean:
	rm -f cabal.project.freeze # we use nix
	rm -f .ghc.environment*
	rm -fR dist dist-*

ghcid: clean 
	nix-shell --run "ghcid -s \"import Main\" -c \"make update-cabal && cabal new-repl \" -T \"main\" test:unit"

haddock:
	cabal new-haddock all

haddock-hackage:
	cabal new-haddock all --haddock-for-hackage --haddock-option=--hyperlinked-source
	echo "the hackage ui doesn't accept the default format, use command instead"
	cabal upload -d --publish ./dist-newstyle/*-docs.tar.gz


sdist: update-cabal haddock
	cabal new-sdist all
