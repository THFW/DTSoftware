;--------------------------
; write_EOI:
;--------------------------
write_master_EOI:
	mov al, 00100000B				; OCW2 select, EOI
	out MASTER_OCW2_PORT, al
	ret
        
write_slave_EOI:
    mov al,  00100000B
    out SLAVE_OCW2_PORT, al
    ret

;----------------------------
; read_isr:
;----------------------------
read_master_isr:
	mov al, 00001011B			; OCW3 select, read ISR
	out MASTER_OCW3_PORT, al
	jmp $+2
	in al, MASTER_OCW3_PORT
	ret
    
read_slave_isr:
	mov al, 00001011B
    out SLAVE_OCW3_PORT, al
    jmp $+2
    in al, SLAVE_OCW3_PORT
    ret
    
;-----------------------------
; read_irr:
;-----------------------------
read_master_irr:
	mov al, 00001010B			; OCW3 select, read IRR	
	out MASTER_OCW3_PORT, al
	jmp $+2
	in al, MASTER_OCW3_PORT
	ret

read_slave_irr:
    mov al, 00001010B
    out SLAVE_OCW3_PORT, al
    jmp $+2
    in al, SLAVE_OCW3_PORT
    ret
        
;-----------------------------
; read_imr:
;-----------------------------
read_master_imr:
	in al, MASTER_IMR_PORT
	ret
        
read_slave_imr:
    in al, SLAVE_IMR_PORT
    ret
    
;------------------------------
; send_smm_command
;------------------------------
send_smm_command:
	mov al, 01101000B			; SMM=ESMM=1, OCW3 select
	out MASTER_OCW3_PORT, al	
	ret
    