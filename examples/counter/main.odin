package counter

import "core:fmt"

import coroutine "../../../coroutines"

counter :: proc(arg: rawptr) {
    n := int(uintptr(arg))
    for i in 0..<n {
        fmt.printfln("[%v] %v", coroutine.id(), i)
        coroutine.yield()
    }
}

main :: proc() {
    coroutine.go(proc(arg: rawptr) {
        fmt.printfln("[%v] Hello from odin Lambda", coroutine.id())
    }, nil)
    coroutine.go(counter, rawptr(uintptr(5)))
    coroutine.go(counter, rawptr(uintptr(10)))
    for coroutine.alive() > 1 do coroutine.yield()
}
