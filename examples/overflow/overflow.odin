// this program is expected to crash
// this doesn't really prove anything because the page below ours is 
// very likely to be unreserved even if we don't reserve a guard page
// i'm keeping this example until i find out how to test that the guard page
// is actually working though, as a record of intention if not a proof of action 
package overflow

import "core:fmt"

import co "../../../coro"

// the guard page allocated by `allocate_stack()` should catch this stack overflow
// the program will then crash, preventing memory corruption
overflow_stack :: proc(cc: co.Caller, i: int) {
    fmt.printfln("%d / INFINITY", i)
    overflow_stack(cc, i+1)
}

main :: proc() {
    overflows := co.create(overflow_stack, 0)
    co.resume(&overflows)
    unreachable() // the stack will have overflown by this point
}