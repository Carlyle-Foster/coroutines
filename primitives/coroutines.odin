package coroutines

import "base:runtime"

import "core:mem"
import "core:mem/virtual"

Coroutine :: struct {
    rsp: rawptr,
    stack: Stack,
}
#assert(offset_of(Coroutine, rsp) == 0)

Caller :: distinct ^Coroutine

Stack :: distinct []byte

allocate_stack :: proc(min_size: int) -> (Stack, runtime.Allocator_Error) #optional_allocator_error {
    page_size := mem.PAGE_SIZE
    size      := runtime.align_forward(min_size, page_size) + page_size

    stack, err := virtual.reserve_and_commit(uint(size))
    if err != nil {
        return nil, err
    }
    // remove read/write permissions from the guard page
    ensure(virtual.protect(raw_data(stack), uint(page_size), {}))
    // skip past the guard page
    stack = stack[page_size:]
    
    return Stack(stack), nil
}

free_stack :: proc(stack: Stack) {
    page_size := mem.PAGE_SIZE

    base := rawptr( uintptr(raw_data(stack)) - uintptr(page_size) )

    virtual.decommit(base, uint(page_size))
    virtual.release(base, uint(page_size))
}

create :: proc(stack: Stack, f: proc(Caller, rawptr), arg: rawptr, on_finish: proc(^Coroutine, rawptr), on_finish_arg: rawptr) -> ^Coroutine {
    assert(len(stack) % 16 == 0)

    reserved := runtime.align_forward(size_of(Coroutine), int(16))
    // this is one byte AFTER the top of the stack
    rsp := raw_data(stack[len(stack) - reserved:])

    // this doesn't overlap the stack since it goes upward
    coroutine := cast(^Coroutine)rsp
    coroutine^ = {
        rsp,
        stack,
    }
    asm_init(coroutine, arg, f, on_finish, on_finish_arg)

    return coroutine
}

swap_stacks :proc "c" (^Coroutine) -> (finished: bool):
    asm_swap_stacks

when ODIN_OS != .Windows && ODIN_ARCH == .amd64 {
    foreign import assembly "amd64_posix.asm"
} else when ODIN_OS == .Windows && ODIN_ARCH == .amd64 {
    foreign import assembly "amd64_windows.asm"
} else {
    #assert(false, "unsupported architecture")
}
foreign assembly {
    @(private)
    asm_init        :: proc "odin" (^Coroutine, rawptr, proc"odin"(Caller, rawptr), proc"odin"(^Coroutine, rawptr), rawptr) ---
    asm_swap_stacks :: proc "c"    (^Coroutine) -> bool ---
}
