; this file uses a NASM/intel dialect

; TODO: ARM support

; Linux x86_64 call convention
; %rdi, %rsi, %rdx, %rcx, %r8, and %r9

bits 64

section .note.GNU-stack

section .text

extern __finish_current

global coroutine_start
global coroutine_restore_context

extern __go
extern __yield
extern __wait_until

global coroutine_go
global coroutine_yield
global coroutine_wait_until

coroutine_go:
    mov rcx, rdx
    mov rdx, rsp
    jmp [rel __go wrt ..got]

coroutine_yield:
    mov rsi, rdi
    mov rdi, rsp
    jmp [rel __yield wrt ..got]

coroutine_wait_until:
    mov rcx, rdx
    mov rdx, rsp
    jmp [rel __wait_until wrt ..got]

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
