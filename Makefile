
all: test

test: beam
	test/literals.escript
	test/numbers.escript
	test/strings.escript
	test/objects.escript
	test/arrays.escript
	test/compound.escript

BUILT=\
    ebin/ejson.beam \
	ebin/ejson_decode.beam \
	ebin/ejson_encode.beam \
	ebin/mochijson2.beam

beam: $(BUILT)

ebin/%.beam: src/%.erl
	@mkdir -p ebin
	erlc -o ebin/ $<
