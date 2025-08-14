; this file uses a NASM/intel dialect

bits 64

section .note.GNU-stack

section .text

extern __finish_current

extern __go
extern __yield
extern __sleep_read
extern __sleep_write

global coroutine_yield
global coroutine_sleep_read
global coroutine_sleep_write

global coroutine_go
global coroutine_start
global coroutine_setup_context
global coroutine_restore_context

coroutine_go:
    mov rcx, rdx
    mov rdx, rsp
    jmp [rel __go wrt ..got]

coroutine_yield:
    mov rsi, rdi
    mov rdi, rsp
    jmp [rel __yield wrt ..got]

coroutine_sleep_read:
    mov rdx, rsi
    mov rsi, rsp
    jmp [rel __sleep_read wrt ..got]

coroutine_sleep_write:
    mov rdx, rsi
    mov rsi, rsp
    jmp [rel __sleep_write wrt ..got]

coroutine_start:
    mov rsp, rdx ; switch stacks

    ; setup the stack
    push qword 0    ; for alignment
    push rcx        ; implicit context pointer, popped by finish_current
    lea rax, [rel finish_current]
    push rax

    mov rax, rdi    ; save f in rax
     
    mov rdi, rsi    ; arg (for f)
    mov rsi, rcx    ; implicit context pointer (for f)

    jmp rax         ; jump to f

finish_current:
    pop rdi ; implicit context pointer

    jmp [rel __finish_current wrt ..got]

coroutine_restore_context:
    mov rsp, rdi
    ret
