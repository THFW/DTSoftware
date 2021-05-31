Init8259A:
    ; 初始化主片
    ; 1) 先写 ICW1
	mov al, 0x11					; IC4 = 1, ICW4-write required
	out MASTER_ICW1_PORT, al
	
    call delay
    
    ; 2) 接着写 ICW2
	mov al, 0x20					; interrupt vector = 0x20
	out MASTER_ICW2_PORT, al
	
    call delay
    
    ; 3) 接着写 ICW3				
	mov al, 0x04					; ICW3[2] = 1, for slave connection
	out MASTER_ICW3_PORT, al
	
    call delay
    
    ; 4) 接着写 ICW4
	mov al, 0x01					; ICW4[0] = 1, for Intel Architecture
	out MASTER_ICW4_PORT, al
	
    call delay
    
    ; 初始化从片
    ; 1) 先写 ICW1
	mov al, 0x11					; IC4 = 1, ICW4-write required
	out SLAVE_ICW1_PORT, al
	
    call delay
    
    ; 2) 接着写 ICW2
	mov al, 0x28					; interrupt vector = 0x28
	out SLAVE_ICW2_PORT, al
    
	call delay
    
    ; 3) 接着写 ICW3				
	mov al, 0x02					; ICW3[1] = 1, connect to master IR2
	out SLAVE_ICW3_PORT, al
    
	call delay
    
    ; 4) 接着写 ICW4
	mov al, 0x01					; for Intel Architecture
	out SLAVE_ICW4_PORT, al		
    
    call delay
    
	ret