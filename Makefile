
JISON_VERSION := $(shell node ../../lib/cli.js -V 2> /dev/null )

ifndef JISON_VERSION
	JISON = sh node_modules/.bin/jison
else
	JISON = node ../../lib/cli.js
endif




all: build test

prep: npm-install

npm-install:
	npm install

npm-update:
	ncu -a --packageFile=package.json

build:
ifeq ($(wildcard ./node_modules/.bin/jison),)
	$(error "### FAILURE: Make sure you have run 'make prep' before as the jison compiler is unavailable! ###")
endif

	node __patch_version_in_js.js

	$(JISON) bnf.y bnf.l
	mv bnf.js parser.js

	$(JISON) ebnf.y
	mv ebnf.js transform-parser.js

test:
	node_modules/.bin/mocha --timeout 18000 --check-leaks --globals assert tests/


# increment the XXX <prelease> number in the package.json file: version <major>.<minor>.<patch>-<prelease>
bump:
	npm version --no-git-tag-version prerelease

git-tag:
	node -e 'var pkg = require("./package.json"); console.log(pkg.version);' | xargs git tag

publish:
	npm run pub






clean:
	-rm -f parser.js
	-rm -f transform-parser.js
	-rm -f bnf.js
	-rm -f ebnf.js
	-rm -rf node_modules/
	-rm -f package-lock.json

superclean: clean
	-find . -type d -name 'node_modules' -exec rm -rf "{}" \;





.PHONY: all prep npm-install build test clean superclean bump git-tag publish
