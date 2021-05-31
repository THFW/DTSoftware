%include "inc.asm"

PageDirBase0    equ    0x200000
PageTblBase0    equ    0x201000
PageDirBase1    equ    0x700000
PageTblBase1    equ    0x701000

ObjectAddrX     equ    0x401000
TargetAddrY     equ    0xD01000
TargetAddrZ     equ    0xE01000

org 0x9000

jmp ENTRY_SEGMENT

[section .gdt]
; GDT definition
;                                       段基址，           段界限，       段属性
GDT_ENTRY         :     Descriptor        0,                0,           0
CODE32_DESC       :     Descriptor        0,        Code32SegLen - 1,    DA_C + DA_32
VIDEO_DESC        :     Descriptor     0xB8000,         0x07FFF,         DA_DRWA + DA_32
DATA32_DESC       :     Descriptor        0,        Data32SegLen - 1,    DA_DRW + DA_32
STACK32_DESC      :     Descriptor        0,         TopOfStack32,       DA_DRW + DA_32
PAGE_DIR_DESC0    :     Descriptor    PageDirBase0,       4095,          DA_DRW + DA_32
PAGE_TBL_DESC0    :     Descriptor    PageTblBase0,       1023,          DA_DRW + DA_LIMIT_4K + DA_32
PAGE_DIR_DESC1    :     Descriptor    PageDirBase1,       4095,          DA_DRW + DA_32
PAGE_TBL_DESC1    :     Descriptor    PageTblBase1,       1023,          DA_DRW + DA_LIMIT_4K + DA_32
FLAT_MODE_RW_DESC :     Descriptor        0,             0xFFFFF,        DA_DRW + DA_LIMIT_4K + DA_32
; GDT end

GdtLen    equ   $ - GDT_ENTRY

GdtPtr:
          dw   GdtLen - 1
          dd   0
          
          
; GDT Selector

Code32Selector      equ (0x0001 << 3) + SA_TIG + SA_RPL0
VideoSelector       equ (0x0002 << 3) + SA_TIG + SA_RPL0
Data32Selector      equ (0x0003 << 3) + SA_TIG + SA_RPL0
Stack32Selector     equ (0x0004 << 3) + SA_TIG + SA_RPL0
PageDirSelector0    equ (0x0005 << 3) + SA_TIG + SA_RPL0
PageTblSelector0    equ (0x0006 << 3) + SA_TIG + SA_RPL0
PageDirSelector1    equ (0x0007 << 3) + SA_TIG + SA_RPL0
PageTblSelector1    equ (0x0008 << 3) + SA_TIG + SA_RPL0
FlatModeRWSelector  equ (0x0009 << 3) + SA_TIG + SA_RPL0
; end of [section .gdt]

TopOfStack16    equ 0x7c00

[section .dat]
[bits 32]
DATA32_SEGMENT:
    DTOS               db  "D.T.OS!", 0
    DTOS_LEN           equ $ - DTOS
    DTOS_OFFSET        equ DTOS - $$
    HELLO_WORLD        db  "Hello World!", 0
    HELLO_WORLD_LEN    equ $ - HELLO_WORLD
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
    
    mov ax, FlatModeRWSelector
    mov es, ax
    
    mov esi, DTOS_OFFSET
    mov edi, TargetAddrY
    mov ecx, DTOS_LEN
    
    call MemCpy32
    
    mov esi, HELLO_WORLD_OFFSET
    mov edi, TargetAddrZ
    mov ecx, HELLO_WORLD_LEN
    
    call MemCpy32
    
    mov eax, PageDirSelector0
    mov ebx, PageTblSelector0
    mov ecx, PageTblBase0
    
    call InitPageTable
    
    mov eax, PageDirSelector1
    mov ebx, PageTblSelector1
    mov ecx, PageTblBase1
    
    call InitPageTable
    
    mov eax, ObjectAddrX   ; 0x401000
    mov ebx, TargetAddrY   ; 0xD01000
    mov ecx, PageDirBase0
    
    call MapAddress
    
    mov eax, ObjectAddrX   ; 0x401000
    mov ebx, TargetAddrZ   ; 0xE01000
    mov ecx, PageDirBase1
    
    call MapAddress
    
    mov eax, PageDirBase0
    
    call SwitchPageTable
    
    mov ax, FlatModeRWSelector
    mov ds, ax
    mov ebp, ObjectAddrX
    mov bx, 0x0C
    mov dh, 12
    mov dl, 33
    
    call PrintString
    
    mov eax, PageDirBase1
    
    call SwitchPageTable
    
    mov ax, FlatModeRWSelector
    mov ds, ax
    mov ebp, ObjectAddrX
    mov bx, 0x0C
    mov dh, 13
    mov dl, 31
    
    call PrintString
    
    jmp $

; es  --> flat mode
; eax --> virtual address
; ebx --> target  address
; ecx --> page directory base
MapAddress:
    push edi
    push esi 
    push eax    ; [esp + 8]
    push ebx    ; [esp + 4]
    push ecx    ; [esp]
    
    ; 1. 取虚地址高 10 位， 计算子页表在页目录中的位置
    mov eax, [esp + 8]
    shr eax, 22
    and eax, 1111111111b
    shl eax, 2
    
    ; 2. 取虚地址中间 10 位， 计算物理地址在子页表中的位置
    mov ebx, [esp + 8]
    shr ebx, 12
    and ebx, 1111111111b
    shl ebx, 2
    
    ; 3. 取子页表起始地址
    mov esi, [esp]
    add esi, eax
    mov edi, [es:esi]
    and edi, 0xFFFFF000
    
    ; 4. 将目标地址写入子页表的对应位置
    add edi, ebx
    mov ecx, [esp + 4]
    and ecx, 0xFFFFF000
    or  ecx, PG_P | PG_USU | PG_RWW
    mov [es:edi], ecx
    
    pop ecx
    pop ebx
    pop eax
    pop esi
    pop edi
    
    ret

; es    --> flat mode selector
; ds:si --> source
; es:di --> destination
; cx    --> length
MemCpy32:
    push esi
    push edi
    push ecx
    push ax
    
    cmp esi, edi
    
    ja btoe
    
    add esi, ecx
    add edi, ecx
    dec esi
    dec edi
    
    jmp etob
    
btoe:
    cmp ecx, 0
    jz done
    mov al, [ds:esi]
    mov byte [es:edi], al
    inc esi
    inc edi
    dec ecx
    jmp btoe
    
etob: 
    cmp ecx, 0
    jz done
    mov al, [ds:esi]
    mov byte [es:edi], al
    dec esi
    dec edi
    dec ecx
    jmp etob

done:   
    pop ax
    pop ecx
    pop edi
    pop esi
    ret
    
; eax --> page dir base selector
; ebx --> page table base selector 
; ecx --> page table base
InitPageTable:
    push es
    push eax  ; [esp + 12]
    push ebx  ; [esp + 8]
    push ecx  ; [esp + 4]
    push edi  ; [esp]
    
    mov es, ax
    mov ecx, 1024    ;  1K sub page tables
    mov edi, 0
    mov eax, [esp + 4]
    or  eax, PG_P | PG_USU | PG_RWW
    
    cld
    
stdir:
    stosd
    add eax, 4096
    loop stdir
    
    mov ax, [esp + 8]
    mov es, ax
    mov ecx, 1024 * 1024   ; 1M pages
    mov edi, 0
    mov eax, PG_P | PG_USU | PG_RWW
    
    cld
    
sttbl:
    stosd
    add eax, 4096
    loop sttbl
    
    pop edi
    pop ecx
    pop ebx
    pop eax
    pop es
    
    ret   

; eax --> page directory base
SwitchPageTable:
    push eax
    
    mov eax, cr0
    and eax, 0x7FFFFFFF
    mov cr0, eax
    
    mov eax, [esp]
    mov cr3, eax
    mov eax, cr0
    or  eax, 0x80000000
    mov cr0, eax
    
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