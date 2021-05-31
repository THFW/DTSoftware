%include "inc.asm"

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
SYSDAT32_DESC   :     Descriptor        0,        SysDat32SegLen -1,   DA_DR + DA_32
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
SysDat32Selector equ (0x0005 << 3) + SA_TIG + SA_RPL0
; end of [section .gdt]

TopOfStack16    equ 0x7c00

[section .d16]
DATA16_SEGMENT:
    MEM_ERR_MSG      db  "[FAILED] memory check error..."
    MEM_ERR_MSG_LEN  equ $ - MEM_ERR_MSG
Data16SegLen   equ $ - DATA16_SEGMENT

[section .dat]
[bits 32]
DATA32_SEGMENT:
    DTOS               db  "D.T.OS!", 0
    DTOS_OFFSET        equ DTOS - $$
    HELLO_WORLD        db  "Hello World!", 0
    HELLO_WORLD_OFFSET equ HELLO_WORLD - $$

Data32SegLen equ $ - DATA32_SEGMENT

[section .sysdat]
SYSDAT32_SEGMENT:
    MEM_SIZE              times    4      db  0      ; int mem_size = 0;
    MEM_SIZE_OFFSET       equ      MEM_SIZE - $$
    MEM_ARDS_NUM          times    4      db  0      ; int mem_ards_num = 0;
    MEM_ARDS_NUM_OFFSET   equ      MEM_ARDS_NUM - $$
    MEM_ARDS              times 64 * 20   db  0      ; int mem_ards = 0;
    MEM_ARDS_OFFSET       equ      MEM_ARDS - $$

SysDat32SegLen  equ  $ - SYSDAT32_SEGMENT

[section .s16]
[bits 16]
ENTRY_SEGMENT:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, TopOfStack16
    
    ; get system memory information
    call InitSysMemBuf
    
    cmp eax, 0
    jnz CODE16_MEM_ERROR
    
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
    
    mov esi, SYSDAT32_SEGMENT
    mov edi, SYSDAT32_DESC
    
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

CODE16_MEM_ERROR:
    mov bp, MEM_ERR_MSG
    mov cx, MEM_ERR_MSG_LEN
    call Print
    jmp $

; es:bp --> string address
; cx    --> string length
Print:
    mov dx, 0
    mov ax, 0x1301
    mov bx, 0x0007
    int 0x10
    ret
    
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

;
;
GetMemSize:
    push eax
    push ebx
    push ecx
    push edx
    
    mov dword [MEM_SIZE], 0
    
    xor eax, eax
    mov eax, 0xE801
    
    int 0x15
    
    jc geterr
    
    shl eax, 10   ; eax = eax * 1024;
    
    shl ebx, 6    ; ebx = ebx * 64;
    shl ebx, 10   ; ebx = ebx * 1024;
    
    mov ecx, 1
    shl ecx, 20   ; ecx = 1MB
    
    add dword [MEM_SIZE], eax
    add dword [MEM_SIZE], ebx
    add dword [MEM_SIZE], ecx
    
    jmp getok
    
geterr:
    mov dword [MEM_SIZE], 0
    
getok:

    pop edx
    pop ecx
    pop ebx
    pop eax
    
    ret

; return 
;    eax  --> 0 : succeed      1 : failed
InitSysMemBuf: 
     push edi
     push ebx
     push ecx
     push edx
     
     call GetMemSize
     
     mov edi, MEM_ARDS
     mov ebx, 0
     
doloop:
     mov eax, 0xE820
     mov edx, 0x534D4150
     mov ecx, 20
     
     int 0x15
     
     jc memerr
     
     cmp dword [edi + 16], 1
     jne next
     
     mov eax, [edi]
     add eax, [edi + 8]
     
     cmp dword [MEM_SIZE], eax
     jnb next
     
     mov dword [MEM_SIZE], eax

next:
     add edi, 20
     inc dword [MEM_ARDS_NUM]

     cmp ebx, 0
     jne doloop
     
     mov eax, 0
     
     jmp memok

memerr:
     mov dword [MEM_SIZE], 0
     mov dword [MEM_ARDS_NUM], 0
     mov eax, 1
     
memok:     
     
     pop edx
     pop ecx
     pop ebx
     pop edi
     
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
    
    jmp $


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