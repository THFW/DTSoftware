%include "inc.asm"

org 0x9000

jmp CODE16_SEGMENT

[section .gdt]
; GDT definition
;                                 段基址，       段界限，       段属性
GDT_ENTRY       :     Descriptor    0,            0,           0
CODE32_DESC     :     Descriptor    0,    Code32SegLen  - 1,   DA_C + DA_32
; GDT end

GdtLen    equ   $ - GDT_ENTRY

GdtPtr:
          dw   GdtLen - 1
          dd   0
          
          
; GDT Selector

Code32Selector    equ (0x0001 << 3) + SA_TIG + SA_RPL0

; end of [section .gdt]


[section .s16]
[bits 16]
CODE16_SEGMENT:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    
    ; initialize GDT for 32 bits code segment
    mov eax, 0
    mov ax, cs
    shl eax, 4
    add eax, CODE32_SEGMENT
    mov word [CODE32_DESC + 2], ax
    shr eax, 16
    mov byte [CODE32_DESC + 4], al
    mov byte [CODE32_DESC + 7], ah
    
    ; initialize GDT pointer struct
    mov eax, 0
    mov ax, ds
    shl eax, 4
    add eax, GDT_ENTRY
    mov dword [GdtPtr + 2], eax

    ; 1. load GDT
    lgdt [GdtPtr]
    
    ; 2. close interrupt
    cli 
    
    ; 3. open A20
    in al, 0x92
    or al, 00000010b
    out 0x92, al
    
    ; 4. enter protect mode
    mov eax, cr0
    or eax, 0x01
    mov cr0, eax
    
    ; 5. jump to 32 bits code
    jmp dword Code32Selector : 0

[section .s32]
[bits 32]
CODE32_SEGMENT:
    mov eax, 0
    jmp CODE32_SEGMENT

Code32SegLen    equ    $ - CODE32_SEGMENT