$(shell mkdir -p build)

.PHONY: examples
examples: build/counter build/echo build/lexer

build/counter: examples/counter/* lib.odin coroutine.asm
	odin build examples/counter -debug -out:$@

build/echo: examples/echo/* lib.odin coroutine.asm
	odin build examples/echo -debug -out:$@

build/lexer: examples/lexer/* lib.odin coroutine.asm
	odin build examples/lexer -debug -out:$@
