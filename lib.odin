package coroutines

import "core:fmt"

import c "core:c/libc"

import "core:sys/linux"

foreign import assembly "coroutine.asm"
@(link_prefix="coroutine_", default_calling_convention="odin")
foreign assembly {
    yield       :: proc() ---
    sleep_read  :: proc(fd: linux.Fd) ---
    sleep_write :: proc(fd: linux.Fd) ---

    // TODO(carlyle): this shouldn't require an explicit calling convention, no?
    go              :: proc(f: proc"odin"(rawptr), arg: rawptr) ---
    start           :: proc(f: proc"odin"(arg: rawptr), arg: rawptr, rsp: rawptr) ---
    restore_context :: proc(rsp: rawptr) ---
}

STACK_CAPACITY: uint = 1024 * 64

Context :: struct {
    rsp: rawptr,
    stack_base: rawptr,
    active_id: Maybe(Active_Index),
}

// TODO: coroutines library probably does not work well in multithreaded environment
contexts: [dynamic]Context
dead:   [dynamic]int
current: int

active: [dynamic]int
Active_Index :: distinct int

epoll: linux.Fd

// TODO: ARM support

// Linux x86_64 call convention
// %rdi, %rsi, %rdx, %rcx, %r8, and %r9

ensure_init :: #force_inline proc() {
    if len(contexts) == 0 {
        append(&contexts, Context{ active_id = 0 })
        append(&active, 0)

        epoll_create_err: linux.Errno
        epoll, epoll_create_err = linux.epoll_create1({})
        assert(epoll_create_err == nil)
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

    self := active[current]
    contexts[self].rsp = rsp

    unordered_remove(&active, current)

    fd_copy, dup_err := linux.dup(fd)
    assert(dup_err == nil)

    ctl_err := linux.epoll_ctl(epoll, .ADD, fd_copy, &{ events={ .RDNORM, .ONESHOT }, data={ u64=u64(self) } })
    assert(ctl_err == nil, fmt.tprint(ctl_err))

    switch_context()
}

@(export)
__sleep_write :: proc(fd: linux.Fd, rsp: rawptr) {
    ensure_init()

    self := active[current]
    contexts[self].rsp = rsp

    unordered_remove(&active, current)
    
    fd_copy, dup_err := linux.dup(fd)
    assert(dup_err == nil)
    
    ctl_err := linux.epoll_ctl(epoll, .ADD, fd_copy, &{ events={ .WRNORM, .ONESHOT }, data={ u64=u64(self) } })
    assert(ctl_err == nil, fmt.tprint(ctl_err))

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
    timeout: c.int =  -1 if (len(active) == 0) else 0

    events: [128]linux.EPoll_Event

    event_count, epoll_wait_err := linux.epoll_wait(epoll, raw_data(events[:]), len(events), timeout)
    assert(epoll_wait_err == .NONE)

    for event in events[:event_count] {
        ctx_id := int(event.data.u64)
        append(&active, ctx_id)
        contexts[ctx_id].active_id = Active_Index(len(active)-1)
    }
    assert(len(active) > 0, "deadlock")

    current %= len(active) // in case we came here from __yield()

    restore_context(contexts[active[current]].rsp)
}

@(export)
__go :: proc(f: proc(rawptr), arg: rawptr, rsp: rawptr) {
    ensure_init()

    contexts[active[current]].rsp = rsp

    id := 0
    if len(dead) > 0 {
        id = pop(&dead)
    } else {
        append(&contexts, Context{})
        id = len(contexts)-1

        mmap_err: linux.Errno
        contexts[id].stack_base, mmap_err = linux.mmap(0, STACK_CAPACITY, {.WRITE, .READ}, {.PRIVATE, .STACK, .ANONYMOUS, .GROWSDOWN})
        assert(mmap_err == .NONE)
    }
    append(&active, id)
    current = len(active)-1

    rsp := ([^]rawptr)(contexts[id].stack_base)[STACK_CAPACITY/size_of(rawptr): ]

    start(f, arg, rsp)
}

id :: proc() -> int {
    return active[current] if len(active) > 0 else 0
}

wait :: proc() {
    @(static) waiting_coroutines := 0

    waiting_coroutines += 1
    defer waiting_coroutines -= 1
    assert(waiting_coroutines < len(active), "everyone's waiting")

    for len(active) > 1 {
        yield()
    }
}

wake_up :: proc(id: int) {
    assert(len(contexts) > 0)
    append(&active, id)
    contexts[id].active_id = Active_Index(id)
}
