.MODEL SMALL
.STACK 100H

.DATA

; ===== ARRAYS =====
item_prices DW 10,15,20,25,30
quantities  DW 5 DUP(0)

; ===== STRINGS =====
menuMsg DB 13,10,"===== SMART RETAIL SHOP =====",13,10
        DB "1. Rice      - 10",13,10
        DB "2. Sugar     - 15",13,10
        DB "3. Milk      - 20",13,10
        DB "4. Tea       - 25",13,10
        DB "5. Biscuits  - 30",13,10
        DB "0. Exit",13,10
        DB "Select Option: $"

qtyMsg DB 13,10,"Enter Quantity: $"

.CODE

PRINT MACRO MSG
    MOV AH,09H
    LEA DX,MSG
    INT 21H
ENDM

MAIN PROC
    MOV AX,@DATA
    MOV DS,AX

MENU_LOOP:

    PRINT menuMsg
    
    MOV AH,01H
    INT 21H
    SUB AL,48
    
    CMP AL,0
    JE EXIT_PROGRAM
    
    CMP AL,1
    JL MENU_LOOP
    
    CMP AL,5
    JG MENU_LOOP
    
    MOV BL,AL
    DEC BL
    MOV BH,0
    MOV SI,BX
    SHL SI,1

    PRINT qtyMsg
    
    MOV AH,01H
    INT 21H
    SUB AL,48
    MOV AH,0
    
    MOV quantities[SI],AX

    JMP MENU_LOOP

EXIT_PROGRAM:
    MOV AH,4CH
    INT 21H

MAIN ENDP
END MAIN