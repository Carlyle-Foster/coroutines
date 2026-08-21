package gens

import "core:fmt"

import co "../../../coro"

enerates :: co.Gen

repeater :: proc(g:enerates(int), n, times: int) {
    for _ in 1..=times {
        co.yield(g, n)
    }
    return
}

main :: proc() {
    gen := co.gen(repeater, 1, 2)

    for n in co.next(&gen) {
        fmt.println("got", n)
    }
}