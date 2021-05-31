%include "inc.asm"

PageDirBase    equ    0x200000
PageTblBase    equ    0x201000

org 0x9000

jmp ENTRY_SEGMENT

[section .gdt]
; GDT definition
;                                     段基址，           段界限，       段属性
GDT_ENTRY       :     Descriptor        0,                0,           0
CODE32_DESC     :     Descriptor        0,        Code32SegLen - 1,    DA_C + DA_32
VIDEO_DESC      :     Descriptor     0xB8000,         0x07FFF,         DA_DRWA + DA_32
DATA32_DESC     :     Descriptor        0,        Data32SegLen - 1,    DA_DRW + DA_32
STACK32_DESC    :     Descriptor        0,         TopOfStack32,       DA_DRW + DA_32
PAGE_DIR_DESC   :     Descriptor    PageDirBase,        4095,          DA_DRW + DA_32
PAGE_TBL_DESC   :     Descriptor    PageTblBase,        1023,          DA_DRW + DA_LIMIT_4K + DA_32
; GDT end

GdtLen    equ   $ - GDT_ENTRY

GdtPtr:
          dw   GdtLen - 1
          dd   0
          
          
; GDT Selector

Code32Selector   equ (0x0001 << 3) + SA_TIG + SA_RPL0
VideoSelector    equ (0x0002 << 3) + SA_TIG + SA_RPL0
Data32Selector   equ (0x0003 << 3) + SA_TIG + SA_RPL0
Stack32Selector  equ (0x0004 << 3) + SA_TIG + SA_RPL0
PageDirSelector  equ (0x0005 << 3) + SA_TIG + SA_RPL0
PageTblSelector  equ (0x0006 << 3) + SA_TIG + SA_RPL0
; end of [section .gdt]

TopOfStack16    equ 0x7c00

[section .dat]
[bits 32]
DATA32_SEGMENT:
    DTOS               db  "D.T.OS!", 0
    DTOS_OFFSET        equ DTOS - $$
    HELLO_WORLD        db  "Hello World!", 0
    HELLO_WORLD_OFFSET equ HELLO_WORLD - $$

Data32SegLen equ $ - DATA32_SEGMENT

[section .s16]
[bits 16]
ENTRY_SEGMENT:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, TopOfStack16
    
    ; initialize GDT for 32 bits code segment
    mov esi, CODE32_SEGMENT
    mov edi, CODE32_DESC
    
    call InitDescItem
    
    mov esi, DATA32_SEGMENT
    mov edi, DATA32_DESC
    
    call InitDescItem
    
    mov esi, STACK32_SEGMENT
    mov edi, STACK32_DESC
    
    call InitDescItem
    
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


; esi    --> code segment label
; edi    --> descriptor label
InitDescItem:
    push eax

    mov eax, 0
    mov ax, cs
    shl eax, 4
    add eax, esi
    mov word [edi + 2], ax
    shr eax, 16
    mov byte [edi + 4], al
    mov byte [edi + 7], ah
    
    pop eax
    
    ret

    
[section .s32]
[bits 32]
CODE32_SEGMENT:   
    mov ax, VideoSelector
    mov gs, ax
    
    mov ax, Stack32Selector
    mov ss, ax
    
    mov eax, TopOfStack32
    mov esp, eax
    
    mov ax, Data32Selector
    mov ds, ax
    
    mov ebp, DTOS_OFFSET
    mov bx, 0x0C
    mov dh, 12
    mov dl, 33
    
    call PrintString
    
    mov ebp, HELLO_WORLD_OFFSET
    mov bx, 0x0C
    mov dh, 13
    mov dl, 31
    
    call PrintString
    
    call SetupPage
    
    jmp $

;
;
SetupPage:
    push eax
    push ecx
    push edi
    push es
    
    mov ax, PageDirSelector
    mov es, ax
    mov ecx, 1024    ;  1K sub page tables
    mov edi, 0
    mov eax, PageTblBase | PG_P | PG_USU | PG_RWW
    
    cld
    
stdir:
    stosd
    add eax, 4096
    loop stdir
    
    mov ax, PageTblSelector
    mov es, ax
    mov ecx, 1024 * 1024   ; 1M pages
    mov edi, 0
    mov eax, PG_P | PG_USU | PG_RWW
    
    cld
    
sttbl:
    stosd
    add eax, 4096
    loop sttbl
    
    mov eax, PageDirBase
    mov cr3, eax
    mov eax, cr0
    or  eax, 0x80000000
    mov cr0, eax
    
    pop es
    pop edi
    pop ecx
    pop eax
    
    ret   

; ds:ebp    --> string address
; bx        --> attribute
; dx        --> dh : row, dl : col
PrintString:
    push ebp
    push eax
    push edi
    push cx
    push dx
    
print:
    mov cl, [ds:ebp]
    cmp cl, 0
    je end
    mov eax, 80
    mul dh
    add al, dl
    shl eax, 1
    mov edi, eax
    mov ah, bl
    mov al, cl
    mov [gs:edi], ax
    inc ebp
    inc dl
    jmp print

end:
    pop dx
    pop cx
    pop edi
    pop eax
    pop ebp
    
    ret
    
Code32SegLen    equ    $ - CODE32_SEGMENT

[section .gs]
[bits 32]
STACK32_SEGMENT:
    times 1024 * 4 db 0
    
Stack32SegLen equ $ - STACK32_SEGMENT
TopOfStack32  equ Stack32SegLen - 1