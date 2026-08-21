package simple

import "core:fmt"

import co "../../../coro"

main :: proc() {
    c := co.create(proc(cc: co.Caller) {fmt.printfln("i hope this coroutine finds you well..")})
    co.resume(&c)
    
    fmt.println("(back in the main routine) ..best regards")
}

