package counter

import "core:fmt"

import co "../../../coro"

total := 0

counter :: proc(cc: co.Caller, n: int) {
    for i in 1..=n {
        fmt.printfln("%d / %d", i, n)
        total += 1
        co.pass(cc)
    }
}

main :: proc() {
    counters := []co.Routine{
        co.routine(counter, 5),
        co.routine(counter, 10),
        co.routine(counter, 1),
    }
    for co.parallel_iter(&counters) {
        fmt.println("total =", total)
    }
    
    fmt.println("final total:", total)
}
