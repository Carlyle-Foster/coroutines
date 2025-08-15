package coroutines

import "core:sys/linux"

foreign import assembly "coroutine.asm"
@(link_prefix="coroutine_", default_calling_convention="odin")
foreign assembly {
    /*
    Starts a coroutine to run the proc `f` with `arg` as it's argument.
    It starts running immediately

    Inputs:
    - f: The proc to run
    - arg: An opaque pointer passed to `f`
    */
    go          :: proc(f: proc"odin"(rawptr), arg: rawptr) ---

    /*
    Hands over control to another active coroutine, if any are ready
    */
    yield       :: proc() ---

    /*
    waits until the fille descriptor `fd` receives an event of type `event`

    Inputs:
    - fd: the file descriptor to wait on
    - event: the type of event to wait for (usually .Readable or .Writeable)
    */
    wait_until  :: proc(fd: linux.Fd, event: Event_Kind) ---
}

/*
Waits for all other coroutines to finish, except for other coroutines who are doing likewise
*/
wait_for_others :: proc() {
    g_waiting_coroutines += 1
    defer g_waiting_coroutines -= 1

    for len(active) > 1 {
        yield()

        assert(g_waiting_coroutines <= len(active))

        waiting := g_waiting_coroutines + 1 if g_reset_in_progress else g_waiting_coroutines

        if waiting >= len(active) {
            return // avoids deadlocks
        }
    }
}

/*
Signals another coroutine, causing it to become active

Inputs:
- id: the ID of the coroutine to signal
*/
signal_other :: proc(id: int) {
    assert(len(contexts) > 0)
    append(&active, id)
    contexts[id].active_id = Active_Index(id)
}

/*
Returns the ID of the currently running coroutine

Returns:
- The ID of the currently running coroutine
*/
id :: proc() -> int {
    return active[current] if len(active) > 0 else 0
}

/*
waits for all other coroutines to finish and resets the runtime, is reentrant
*/
reset_runtime :: proc() {
    if g_reset_in_progress {
         return
    }
    g_reset_in_progress = true
    defer g_reset_in_progress = false

    for len(active) > 1 {
        yield()
    }

    for ctx in contexts {
        errno := linux.munmap(ctx.stack_base, STACK_CAPACITY)
        assert(errno == nil)
    }
    delete(contexts)
    delete(active)
    delete(dead)

    errno := linux.close(epoll)
    assert(errno == nil)
}
