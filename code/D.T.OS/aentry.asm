%include "common.asm"

global _start
global AppModInit

extern AppMain
extern MemModInit

[section .text]
[bits 32]
_start:
AppModInit: ; 0xF000
    push ebp
    mov ebp, esp
    
    mov dword [AppMainEntry], AppMain
    
    push HeapSize
    push AppHeapBase
    
    call MemModInit
    
    add esp, 8
    
    leave
    
    ret
    
