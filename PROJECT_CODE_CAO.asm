.MODEL SMALL
.STACK 100H

.DATA


; ARRAY-BASED DATA STORAGE
; All item data stored in parallel arrays, indexed 0..4
; Index: 0=Rice, 1=Sugar, 2=Milk, 3=Tea, 4=Biscuit


prices      DW 10, 15, 20, 25, 30   ; Price array (Rice..Biscuit)
quantities  DB  0,  0,  0,  0,  0   ; Quantity array (one byte each)
totals      DW  0,  0,  0,  0,  0   ; Per-item total array

grand_total  DW 0
final_total  DW 0
tax_amount   DW 0
discount_flag DB 0

; Pointer used to track which item index is being processed
current_item DB 0


; MESSAGES


menu_msg DB 13,10,"===== GROCERY SHOP =====",13,10
         DB "1. Rice     - Rs.10",13,10
         DB "2. Sugar    - Rs.15",13,10
         DB "3. Milk     - Rs.20",13,10
         DB "4. Tea      - Rs.25",13,10
         DB "5. Biscuit  - Rs.30",13,10
         DB "0. Checkout",13,10
         DB "Choice (0-5): $"

qty_msg   DB 13,10,"Enter Quantity (0-9): $"

err_msg   DB 13,10,"*** Invalid Input! Please enter a correct number ***",13,10,"$"

header    DB 13,10,"======= INVOICE =======",13,10
          DB "Item       Qty  Price  Total",13,10
          DB "----------------------------",13,10,"$"

tax_lbl   DB 13,10,"Tax   (5%): Rs. $"
sub_lbl   DB 13,10,"Subtotal  : Rs. $"
disc_lbl  DB 13,10,"Discount  : 10% OFF Applied",13,10,"$"
final_lbl DB 13,10,"TOTAL     : Rs. $"
thanks    DB 13,10,"Thank you for shopping!",13,10,"$"
newline   DB 13,10,"$"
space     DB "  $"

; Item name table  each name is exactly 10 chars (padded with spaces), terminated by '$'
; Stored as a flat byte array; each entry = 10 bytes
item_names DB "Rice      $"   ; index 0  (offset 0)
           DB "Sugar     $"   ; index 1  (offset 11)
           DB "Milk      $"   ; index 2  (offset 22)
           DB "Tea       $"   ; index 3  (offset 33)
           DB "Biscuit   $"   ; index 4  (offset 44)

NAME_ENTRY_SIZE EQU 11         ; 10 chars + '$' terminator

.CODE


; MACRO: Print a string by offset address

PRINT MACRO msg
    MOV AH, 09H
    MOV DX, OFFSET msg
    INT 21H
ENDM


; MAIN PROCEDURE

MAIN PROC

    MOV AX, @DATA
    MOV DS, AX

MENU_LOOP:
    PRINT menu_msg

    ; Read one character from keboard 
    MOV AH, 01H
    INT 21H                    ; AL = ASCII of key pressed

    ; Alphanumeric filter: block non-digit characters 
    ; Valid ASCII for '0'..'5' = 30H..35H
    CMP AL, 30H                ; below '0'?
    JB  INPUT_ERROR
    CMP AL, 35H                ; above '5'?
    JA  INPUT_ERROR

    ; Convert ASCII digit to integer (0..5)
    SUB AL, 30H

    ; Checkout
    CMP AL, 0
    JE  BILL

    ; Store chosen item index (1-based input -> 0-based array) 
    DEC AL                     ; make 0-based (1->0, 2->1, ... 5->4)
    MOV current_item, AL

    ; Ask for quantity 
    PRINT qty_msg

    MOV AH, 01H
    INT 21H                    ; AL = ASCII digit

    ; Quantity filter: must be '0'..'9' (30H..39H) 
    CMP AL, 30H
    JB  INPUT_ERROR
    CMP AL, 39H
    JA  INPUT_ERROR

    SUB AL, 30H                ; convert to integer 0..9

    ; Store quantity into quantities array 
    ; Use SI as byte index into quantities[]
    MOV BL, current_item       ; BL = 0-based item index
    MOV BH, 0
    MOV SI, BX                 ; SI = index
    MOV quantities[SI], AL     ; quantities[index] = entered qty

    JMP MENU_LOOP

INPUT_ERROR:
    ; ---- Display error and return to menu ----
    PRINT err_msg
    JMP MENU_LOOP

BILL:
    CALL COMPUTE_TOTALS
    CALL SHOW_BILL

    MOV AH, 4CH
    INT 21H

MAIN ENDP

; PRINT_NUM — prints AX as a decimal number
; Destroys: AX, BX, CX, DX

PRINT_NUM PROC

    MOV  BX, 10
    MOV  CX, 0

DIVLOOP:
    MOV  DX, 0
    DIV  BX                    ; AX = quotient, DX = remainder
    PUSH DX                    ; push digit (least significant first)
    INC  CX
    CMP  AX, 0
    JNE  DIVLOOP

PRINTLOOP:
    POP  DX
    ADD  DL, 30H               ; convert digit to ASCII
    MOV  AH, 02H
    INT  21H
    LOOP PRINTLOOP

    RET
PRINT_NUM ENDP


; COMPUTE_TOTALS
; Iterates over all 5 items using SI as array index.
; totals[i] = quantities[i] * prices[i]
; grand_total = sum of all totals + 5% tax
; final_total = grand_total with optional 10% discount

COMPUTE_TOTALS PROC

    MOV grand_total, 0         ; reset accumulator

    MOV SI, 0                  ; SI = loop counter / byte index
    MOV CX, 5                  ; 5 items

CALC_LOOP:
    ; Load quantity (byte array, index = SI) 
    MOV AL, quantities[SI]
    MOV AH, 0                  ; zero-extend to 16-bit

    ; Load price (word array, index = SI*2)
    MOV BX, SI
    SHL BX, 1                  ; BX = SI * 2 (word offset)
    MOV DX, prices[BX]         ; DX = price for this item

    ; Multiply: qty * price 
    ; MUL with a 16-bit operand: DX:AX = AX * DX
    ; Result fits in AX for our price range (max 9 * 30 = 270)

    MUL DX                     ; AX = qty * price  (result in AX)

    ; Store into totals[SI] (word array)
    MOV BX, SI
    SHL BX, 1
    MOV totals[BX], AX

    ; Accumulate grand total
    ADD grand_total, AX

    INC SI
    LOOP CALC_LOOP

    ; Calculate 5% tax on subtotal  
    ; Using full 16-bit division
    
    MOV AX, grand_total
    MOV BX, 5
    MOV DX, 0
    MUL BX                     ; AX = grand_total * 5
    MOV BX, 100
    DIV BX                     ; AX = (grand_total * 5) / 100
    MOV tax_amount, AX
    MOV DX, 0
    ADD grand_total, AX        ; grand_total now includes tax
                                              
                                              
    ; Apply 10% discount if grand_total >= 50 
    ; Using full 16-bit division
    MOV AX, grand_total
    CMP AX, 50
    JB  NO_DISC

    ; Discount: final = grand_total * 9 / 10
    MOV BX, 9
    MOV DX, 0                  ; clear DX before MUL (16-bit)
    MUL BX                     ; DX:AX = grand_total * 9
    MOV BX, 10
    DIV BX                     ; AX = (grand_total * 9) / 10
                               ; DX = remainder (discarded)
    MOV final_total, AX
    MOV discount_flag, 1
    RET

NO_DISC:
    MOV final_total, AX
    MOV discount_flag, 0
    RET

COMPUTE_TOTALS ENDP

; SHOW_BILL
; Iterates over items with SI; skips items with qty = 0.
; Prints item name (from item_names flat array), qty, price, total.  

SHOW_BILL PROC

    PRINT header

    MOV SI, 0                  ; SI = item index (0..4)
    MOV CX, 5

BILL_LOOP:
    ; Skip item if quantity is 0
    MOV AL, quantities[SI]
    CMP AL, 0
    JE  NEXT_ITEM

    ; Print item name from flat name array 
    ; Offset into item_names = SI * NAME_ENTRY_SIZE
    PUSH SI
    PUSH CX

    MOV  AX, SI
    MOV  BX, NAME_ENTRY_SIZE
    MUL  BX                    ; AX = SI * 11
    MOV  DX, OFFSET item_names
    ADD  DX, AX                ; DX = address of name string
    MOV  AH, 09H
    INT  21H                   ; print name (ends at '$')

    ; Print quantity 
    MOV  BX, SI                ; restore SI into BX for array access
    MOV  DL, quantities[BX]
    ADD  DL, 30H               ; ASCII
    MOV  AH, 02H
    INT  21H

    ; Print two spaces
    MOV  DL, ' '
    INT  21H
    INT  21H

    ; Print price
    SHL  BX, 1                 ; BX = SI*2 for word array
    MOV  AX, prices[BX]
    CALL PRINT_NUM

    MOV  DL, ' '
    MOV  AH, 02H
    INT  21H
    INT  21H

    ; Print item total 
    MOV  BX, SI
    SHL  BX, 1
    MOV  AX, totals[BX]
    CALL PRINT_NUM

    ; Newline 
    MOV  DL, 13
    MOV  AH, 02H
    INT  21H
    MOV  DL, 10
    INT  21H

    POP  CX
    POP  SI

NEXT_ITEM:
    INC  SI
    LOOP BILL_LOOP

    ; Print tax line
    PRINT tax_lbl
    MOV AX, tax_amount
    CALL PRINT_NUM

    ; Print subtotal (grand_total already includes tax)
    PRINT sub_lbl
    MOV AX, grand_total
    CALL PRINT_NUM

    ; Discount and final total
    CMP discount_flag, 1
    JNE NO_DISC_PRINT

    PRINT disc_lbl
    PRINT final_lbl
    MOV AX, final_total
    CALL PRINT_NUM
    JMP BILL_END

NO_DISC_PRINT:
    PRINT final_lbl
    MOV AX, final_total
    CALL PRINT_NUM

BILL_END:
    PRINT thanks
    RET

SHOW_BILL ENDP

END MAIN