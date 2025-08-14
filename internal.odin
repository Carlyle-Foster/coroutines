package coroutines

// import "core:fmt"

import c "core:c/libc"

import "core:sys/linux"

foreign import assembly "coroutine.asm"
@(link_prefix="coroutine_", default_calling_convention="odin")
foreign assembly {
    start           :: proc(f: proc"odin"(arg: rawptr), arg: rawptr, rsp: rawptr) ---
    restore_context :: proc(rsp: rawptr) ---
}

@(private)
ensure_init :: #force_inline proc() {
    if len(contexts) == 0 {
        append(&contexts, Context{ active_id = 0 })
        append(&active, 0)

        epoll_create_err: linux.Errno
        epoll, epoll_create_err = linux.epoll_create1({})
        assert(epoll_create_err == nil)
    }
}

@(private, export)
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

@(private, export)
__yield :: proc(rsp: rawptr) {
    ensure_init()

    contexts[active[current]].rsp = rsp

    current += 1

    switch_context()
}

@(private, export)
__wait_until :: proc(fd: linux.Fd, event: Event_Kind, rsp: rawptr) {
    fd := fd
    
    ensure_init()

    self := active[current]
    contexts[self].rsp = rsp

    unordered_remove(&active, current)

    errno: linux.Errno
    fd, errno = linux.dup(fd)
    assert(errno == nil)
    errno = linux.epoll_ctl(
        epoll,
        .ADD,
        fd,
        &{ events={ .RDNORM if event == .Readable else .WRNORM, .ONESHOT },
        data={ u64=u64(self) } },
    )
    assert(errno == nil)

    switch_context()
}

@(private, export)
__finish_current :: proc() {
    assert(id() != 0)

    append(&dead, active[current])
    unordered_remove(&active, current)

    switch_context()
}

@(private)
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
