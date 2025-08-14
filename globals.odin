package coroutines

import "core:sys/linux"

STACK_CAPACITY: uint = 1024 * 64

// TODO: coroutines library probably does not work well in multithreaded environment
contexts: [dynamic]Context
dead:   [dynamic]int
current: int

active: [dynamic]int

epoll: linux.Fd