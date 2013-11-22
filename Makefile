LIBDIR=$(shell erl -eval 'io:format("~s~n", [code:lib_dir()])' -s init stop -noshell)
VERSION=0.3.0
PKGNAME=ejson

all: app beam

app: ebin/$(PKGNAME).app

beam: \
	ebin/ejson.beam \
	ebin/ejson_decode.beam \
	ebin/ejson_encode.beam

ebin/$(PKGNAME).app: src/$(PKGNAME).app.in
	@sh $< $(VERSION)

ebin/%.beam: src/%.erl
	erlc -o ebin/ $<

clean:
	rm -rf test/*.beam ebin/*.app ebin/*.beam erl_crash.dump

install:
	@for i in ebin/*.beam ebin/*.app src/*.erl src/*.hrl; do install -m 644 -D $$i $(prefix)/$(LIBDIR)/$(PKGNAME)-$(VERSION)/$$i ; done

test: all test-beam
	test/literals.escript
	test/numbers.escript
	test/strings.escript
	test/objects.escript
	test/arrays.escript
	test/compound.escript
	test/timing.escript

test-beam: \
	test/mochijson2.beam \
	test/rfc4627.beam

test/%.beam: test/%.erl
	erlc -o test/ $<
