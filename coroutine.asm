bits 64

default rel

section .note.GNU-stack

section .text

extern coroutine_switch_context
extern __finish_current

global coroutine_yield
global coroutine_sleep_read
global coroutine_sleep_write
global coroutine_restore_context
global coroutine_finish_current
    
coroutine_yield:
    push rdi
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15
    push qword 0  ; coroutine_switch_context assumes the stack is 8 bytes off from being 16 byte aligned at the start

    mov rdi, rsp        ; rsp
    mov rsi, 0          ; sm = SM_NONE
    mov rax, [rel coroutine_switch_context wrt ..got]
    jmp rax

coroutine_sleep_read:
    push rdi
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15
    push qword 0

    mov rdx, rdi        ; fd
    mov rdi, rsp        ; rsp
    mov rsi, 1          ; sm = SM_READ
    mov rax, [rel coroutine_switch_context wrt ..got]
    jmp rax

coroutine_sleep_write:
    push rdi
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15
    push qword 0

    mov rdx, rdi     ; fd
    mov rdi, rsp     ; rsp
    mov rsi, 2       ; sm = SM_WRITE
    mov rax, [rel coroutine_switch_context wrt ..got]
    jmp rax

coroutine_restore_context:
    mov rsp, rdi
    pop r15     ; for alignment only
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    pop rdi
    ret     ; this should always go to finish_current

coroutine_finish_current:
    push qword 0
    mov rax, [rel __finish_current wrt ..got]
    jmp rax
