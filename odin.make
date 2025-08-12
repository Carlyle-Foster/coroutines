build/counter: examples/counter.c coroutine.h build/coroutine.so
	gcc -I. -Wall -Wextra -ggdb -o build/counter examples/counter.c build/coroutine.so

.PHONY: examples
examples: build/counter build/counter_cpp build/counter_c3 build/echo build/lexer

build/echo: examples/echo.c3 coroutine.c3 build/coroutine.so
	c3c compile -l build/coroutine.so -o build/echo examples/echo.c3 coroutine.c3

build/counter_cpp: examples/counter.cpp coroutine.h build/coroutine.so
	g++ -I. -Wall -Wextra -ggdb -o build/counter_cpp examples/counter.cpp build/coroutine.so

build/counter_c3: examples/counter.c3 coroutine.c3 build/coroutine.so
	c3c compile -l build/coroutine.so -o build/counter_c3 examples/counter.c3 coroutine.c3

build/lexer: examples/lexer.c coroutine.h build/coroutine.so
	gcc -I. -Wall -Wextra -ggdb -o build/lexer examples/lexer.c build/coroutine.so

build/coroutine.so: lib.odin coroutine.asm
	mkdir -p build
	odin build . -debug -build-mode:dynamic -out:$@

build/coroutine.o: coroutine.c coroutine.h
	mkdir -p build
	gcc -Wall -Wextra -ggdb -c -o build/coroutine.o coroutine.c
