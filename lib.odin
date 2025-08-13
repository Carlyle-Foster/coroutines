package coroutines

import c "core:c/libc"

import "core:sys/linux"

foreign import assembly "coroutine.asm"
@(link_prefix="coroutine_", default_calling_convention="odin")
foreign assembly {
    yield       :: proc() ---
    sleep_read  :: proc(fd: linux.Fd) ---
    sleep_write :: proc(fd: linux.Fd) ---

    // TODO(carlyle): this shouldn't require an explicit calling convention, no?
    setup_context   :: proc(rsp: rawptr, f: proc"odin"(arg: rawptr), arg: rawptr) -> rawptr ---
    restore_context :: proc(rsp: rawptr) ---
}

STACK_CAPACITY: uint = 1024 * 64

Context :: struct {
    rsp: rawptr,
    stack_base: rawptr,
}

// TODO: coroutines library probably does not work well in multithreaded environment
contexts: [dynamic]Context
current: int

active: [dynamic]int
dead:   [dynamic]int
asleep: [dynamic]int
polls:  [dynamic]linux.Poll_Fd

// TODO: ARM support
//   Requires modifications in all the @arch places

// Linux x86_64 call convention
// %rdi, %rsi, %rdx, %rcx, %r8, and %r9

ensure_init :: #force_inline proc() {
    if len(contexts) == 0 {
        append(&contexts, Context{})
        append(&active, 0)
    }
}

@(export)
__yield :: proc(rsp: rawptr) {
    ensure_init()

    contexts[active[current]].rsp = rsp

    current += 1

    switch_context()
}

@(export)
__sleep_read :: proc(fd: linux.Fd, rsp: rawptr) {
    ensure_init()

    contexts[active[current]].rsp = rsp

    append(&asleep, active[current])
    unordered_remove(&active, current)

    append(&polls, linux.Poll_Fd{ fd=fd, events={ .RDNORM } })

    switch_context()
}

@(export)
__sleep_write :: proc(fd: linux.Fd, rsp: rawptr) {
    ensure_init()

    contexts[active[current]].rsp = rsp

    append(&asleep, active[current])
    unordered_remove(&active, current)
    
    append(&polls, linux.Poll_Fd{ fd=fd, events={ .WRNORM } })

    switch_context()
}

@(export)
__finish_current :: proc() {
    assert(id() != 0)

    append(&dead, active[current])
    unordered_remove(&active, current)

    switch_context()
}

switch_context :: proc() {
    if len(polls) > 0 {
        timeout: c.int =  -1 if (len(active) == 0) else 0

        _, poll_err := linux.poll(polls[:], timeout)
        assert(poll_err == .NONE)

        for i := 0; i < len(polls); {
            if polls[i].revents > {} {
                id := asleep[i]
                unordered_remove(&polls, i)
                unordered_remove(&asleep, i)
                append(&active, id)
            } else {
                i += 1
            }
        }
    }
    assert(len(active) > 0, "deadlock")
    current %= len(active)

    restore_context(contexts[active[current]].rsp)
}

go :: proc(f: proc(rawptr), arg: rawptr) {
    ensure_init()

    id: int
    if len(dead) > 0 {
        id = pop(&dead)
    } else {
        append(&contexts, Context{})
        id = len(contexts)-1

        mmap_err: linux.Errno
        contexts[id].stack_base, mmap_err = linux.mmap(0, STACK_CAPACITY, {.WRITE, .READ}, {.PRIVATE, .STACK, .ANONYMOUS, .GROWSDOWN})
        assert(mmap_err == .NONE)
    }

    rsp := ([^]rawptr)(contexts[id].stack_base)[STACK_CAPACITY/size_of(rawptr): ]

    contexts[id].rsp = setup_context(rsp, f, arg)

    append(&active, id)
}

wake_up :: proc(id: int) {
    // @speed coroutine_wake_up is linear
    for sleeper in asleep {
        if sleeper == id {
            unordered_remove(&asleep, id)
            unordered_remove(&polls, id)
            append(&active, id)
            return
        }
    }
}

id :: proc() -> int {
    return active[current] if len(active) > 0 else 0
}

alive :: proc() -> int {
    return len(active)
}
