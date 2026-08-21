// a simple runtime that just allocates a new stack for each coroutine
// and frees it on completion, no "pooling" here nosiree
package ex_rt

import "base:intrinsics"

import co   "../../../coro"
import prim "../../../coro/primitives"

STACK_CAPACITY  :: 64 * 1024

create_raw :: proc(f: proc(co.Caller, rawptr), arg: rawptr) -> ^co.Coroutine {
    stack := prim.allocate_stack(STACK_CAPACITY)
    
    return prim.create(stack, f, arg, on_finish, nil)

    on_finish :: proc(coroutine: ^co.Coroutine, _arg: rawptr) {
        prim.free_stack(coroutine.stack)
    }
}