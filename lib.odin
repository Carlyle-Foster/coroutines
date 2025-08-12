package coroutines

import "base:runtime"

import "core:os"
import c "core:c/libc"

import "core:sys/linux"

@(export)
foreign import assembly "coroutine.asm"
@(link_prefix="coroutine_")
foreign assembly {
    yield :: proc() ---

    sleep_read  :: proc(fd: linux.Poll_Fd) ---
    sleep_write :: proc(fd: linux.Poll_Fd) ---

    restore_context :: proc(rsp: rawptr) ---
    finish_current  :: proc() ---
}



STACK_CAPACITY := uint( 1024 * os.get_page_size() )

Context :: struct {
    rsp: rawptr,
    stack_base: rawptr,
}

// TODO: coroutines library probably does not work well in multithreaded environment
current: int
active: [dynamic]int
dead: [dynamic]int
contexts: [dynamic]Context
asleep: [dynamic]int
polls: [dynamic]linux.Poll_Fd

// TODO: ARM support
//   Requires modifications in all the @arch places

Sleep_Mode :: enum {
    None = 0,
    Read,
    Write,
}

// Linux x86_64 call convention
// %rdi, %rsi, %rdx, %rcx, %r8, and %r9

@(export, link_name="coroutine_init")
init :: proc "c" () {
    context = runtime.default_context()

    if len(contexts) != 0 {
        return // already initialized
    }
    append(&contexts, Context{})
    append(&active, 0)
}

@(export, link_prefix="coroutine_")
switch_context :: proc "c" (rsp: rawptr, sm: Sleep_Mode, fd: linux.Fd) {
    context = runtime.default_context()

    contexts[active[current]].rsp = rsp

    switch sm {
    case .None:
        current += 1
    case .Read:
        append(&asleep, active[current])
        unordered_remove(&active, current)

        append(&polls, linux.Poll_Fd{ fd=fd, events={ .RDNORM } })
    case .Write:
        append(&asleep, active[current])
        unordered_remove(&active, current)

        append(&polls, linux.Poll_Fd{ fd=fd, events={ .WRNORM } })
    case: 
        unreachable()
    }

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
    assert(len(active) > 0)
    current %= len(active)
    restore_context(contexts[active[current]].rsp)
}

//TODO(carlyle): ideally we shouldn't export this
@(export)
__finish_current :: proc "c" () {
    context = runtime.default_context()

    assert(active[current] != 0)

    append(&dead, active[current])
    unordered_remove(&active, current)

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
    assert(len(active) > 0)
    current %= len(active)
    restore_context(contexts[active[current]].rsp)
}

@(export, link_prefix="coroutine_")
go :: proc "c" (f: proc(rawptr), arg: rawptr) {
    context = runtime.default_context()

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

    rsp := ([^]rawptr)(contexts[id].stack_base)[STACK_CAPACITY/size_of(rawptr) - 10 : ]
    // @arch
    rsp[9] = rawptr(finish_current)
    rsp[8] = rawptr(f)
    rsp[7] = arg    // push rdi
    rsp[6] = nil    // push rbx
    rsp[5] = nil    // push rbp
    rsp[4] = nil    // push r12
    rsp[3] = nil    // push r13
    rsp[2] = nil    // push r14
    rsp[1] = nil    // push r15
    rsp[0] = nil    // for alignment

    contexts[id].rsp = rsp

    append(&active, id)
}

@(export, link_prefix="coroutine_")
wake_up :: proc "c" (id: int) {
    context = runtime.default_context()

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

@(export, link_prefix="coroutine_")
id :: proc "c" () -> int {
    return active[current]
}

@(export, link_prefix="coroutine_")
alive :: proc "c" () -> int {
    return len(active)
}
