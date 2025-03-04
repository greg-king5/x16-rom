	;;
	;; Commander 16 CodeX Interactive Assembly Environment
	;; 
	;;    Copyright 2020 Michael J. Allison
	;; 
	;;    Redistribution and use in source and binary forms, with or without
	;;    modification, are permitted provided that the following conditions are met:
	;;
	;; 1. Redistributions of source code must retain the above copyright notice,
	;; this list of conditions and the following disclaimer.
	;;
	;; 2. Redistributions in binary form must reproduce the above copyright notice,
	;; this list of conditions and the following disclaimer in the documentation
	;; and/or other materials provided with the distribution.
	;; 
	;;	
	;;    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
	;; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
	;; LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
	;; PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
	;; CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
	;; EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
	;; PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
	;; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
	;; WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
	;; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
	;; POSSIBILITY OF SUCH DAMAGE.

	.psc02                    ; Enable 65c02 instructions
	.feature labels_without_colons

	COL_INST_BYTES=8          ;; Column to start printing the instruction bytes
	COL_INSTRUCTION=17        ;; Column to start printing instruction
	COL_ARGUMENTS=COL_INSTRUCTION + 7

	ROW_MAX = 59

	ROW_FIRST_INSTRUCTION=3   ;; First row to display instructions
	ROW_LAST_INSTRUCTION=ROW_MAX - 4

	DBG_BOX_WIDTH=18          ;; Registers, breakpoints, watch locations
	DBG2_BOX_WIDTH=12         ;; Stack, Zero page registers

	ASSY_LAST_COL=50
	SIDE_BAR_X = ASSY_LAST_COL

	STACK_COL = SIDE_BAR_X + DBG_BOX_WIDTH
	STACK_ROW = DATA_ROW
	STACK_BOX_HEIGHT = 20
	
	REGISTER_COL = SIDE_BAR_X + 6
	REGISTER_ROW = STACK_ROW
	REGISTER_BOX_HEIGHT = 20
	
	PSR_COL = SIDE_BAR_X
	PSR_ROW = REGISTER_ROW + REGISTER_BOX_HEIGHT 
	PSR_BOX_HEIGHT = 15
	PSR_BOX_WIDTH = 15
	
	WATCH_COL = SIDE_BAR_X
	WATCH_ROW = PSR_ROW + PSR_BOX_HEIGHT 
	WATCH_BOX_HEIGHT = 20
	WATCH_BOX_WIDTH = DBG_BOX_WIDTH + DBG2_BOX_WIDTH
	
	VERA_COL = PSR_COL + PSR_BOX_WIDTH
	VERA_ROW = PSR_ROW
	VERA_BOX_WIDTH = 15
	VERA_BOX_HEIGHT = PSR_BOX_HEIGHT

	MEM_NUMBER_OF_BYTES = $10

;;      R0 - Parameters, saved in routines
;;      R1 - Parameters, saved in routines
;;      R2 - Parameters, saved in routines
;;      R3 - Parameters, saved in routines
;;      R4 - Parameters, saved in routines
;;      R5 - Parameters, saved in routines
	
;;      R6
;;      R7
;;      R8
;;      R9
;;      R10 - decoded_str
	
;;      R11 - scratch, not saved
;;      R12 - scratch, not saved
;;      R13 - scratch, not saved
;;      R14 - scratch, not saved
;;      R15 - scratch, not saved

;;      x16 - SCR_COL, SCR_ROW
;;      x17 - ERR_MSG, pointer to error string
;;      x18
;;      x19
;;      x20
	
	.code
	
	.include "bank.inc"
	.include "screen.inc"
	.include "bank_assy.inc"
	.include "petsciitoscr.inc"
	.include "screen.inc"
	.include "utility.inc"
	.include "kvars.inc"
	.include "x16_kernal.inc"
	.include "vera.inc"

	.include "bank_assy_vars.inc"
	.include "screen_vars.inc"
	.include "dispatch_vars.inc"
	.include "decoder_vars.inc"
	.include "encode_vars.inc"
	.include "cx_vars.inc"
	
	.include "dbgctrl.inc"
	.include "decoder.inc"
	.include "dispatch.inc"
	.include "edit.inc"
	.include "encode.inc"
	.include "meta.inc"
	.include "meta_i.inc"
	.include "fio.inc"

;;
;; Main mode display dispatchers
;;
;; Read keys, dispatch based on function key pressed.
;; Since these are relatively short (right now), they are
;; hard coded. Should the volume of these grow too much
;; a data driven (table) version can be coded.
;;
;; Main loop, and dispatch
;; 
	.proc main
;;; -------------------------------------------------------------------------------------
	.code
	
	.export main_entry
	
main_entry: 
	jsr     init_screen_variables

	.ifdef DEV
	;;
	;; Check for 65c02, in case someone is running an old emulator
	;;
	bra     main_65c02_ok
	jsr     clear
	lda     #COLOR_CDR_ERROR
	jsr     screen_set_fg_color
	ldx     #20
	ldy     #25
	callR1  prtstr_at_xy,str_65c02_required
	rts
	.endif

main_65c02_ok
	jsr     bank_initialize
	jsr     init_break_vector

	jsr     clear_program_settings
	
	;; No previous filename since assy_env is starting
	pushBankVar bank_assy
	stz        orig_file_name
	popBank

	;; Save the original stack so a return to the main_loop can be done
	tsx
	lda     bank_assy
	sta     BANK_CTRL_RAM
	stx     original_sp
	stz     BANK_CTRL_RAM

	jsr     clear

main_loop      
	lda     orig_color
	sta     K_TEXT_COLOR

	callR1  print_header,main_header

	jsr     main_display_core

main_dsp_start
main_in 
	setDispatchTable main_dispatch_table

	jsr     get_and_dispatch
	bcs     abort
	
	cmp     #CUR_DN
	bne     @main_chk2
	jsr     assy_down
	jsr     assy_prt_block
	bra     main_in
	
@main_chk2
	cmp     #CUR_UP
	bne     @main_chk3
	jsr     assy_up
	jsr     assy_prt_block
	bra     main_in
@main_chk3
	bra     main_loop

abort
	jsr     dirty_query
	bne     main_in

abort_rts
	jsr     clear
	clc
	jmp     ENTER_BASIC ; Will NOT return
	

;;; -------------------------------------------------------------------------------------
str_is_dirty    .byte "DISCARD CHANGES: Y/N", 0
	             
main_dispatch_table
	.word   file_loop       ; F1
	.word   asm_loop        ; F3
	.word   meta_i_insp     ; F5
	.word   watch_loop      ; F7
	.word   view_loop       ; F2
	.word   main_run_prgrm  ; F4
	.word   0               ; F6

;;; -------------------------------------------------------------------------------------
	.code
	
main_run_prgrm
	pushBankVar  bank_assy
	stz          brk_data_pc
	stz          brk_data_pc+1
	popBank
	
	jsr     assy_run
	bcs     :+
	jsr     save_user_screen
	kerjsr  CLALL
	callR1  wait_for_keypress,str_press_2_continue

	clc
	kerjsr  SCRMOD
	cmp     #MODE_80_60
	beq     :+
	lda     #MODE_80_60
	sec
	kerjsr  SCRMOD   ; back to 80 col

:  
	clc
	rts

main_display_core
	;; If address is set, display the assembly code
	lda     mem_last_addr
	ora     mem_last_addr+1

	bne     :+
	
	ldx    #17
	ldy    #12
	callR1 prtstr_at_xy,version_string

	.ifdef DEV
	vgotoXY  4,12
	jsr     print_logo
	.endif
	
	bra     @main_display_exit

:  
	jsr     assy_prt_block
	
@main_display_exit
	lda     ERR_MSG_L
	ora     ERR_MSG_H
	beq     :+

	lda     #COLOR_CDR_ERROR
	jsr     screen_set_fg_color
	jsr     gotoPrompt
	MoveW   ERR_MSG,r1
	jsr     prtstr
	
:  
	rts


;;; -------------------------------------------------------------------------------------
;;
;; File sub menu
;;
file_loop
	jsr        clear

	lda        orig_color
	sta        K_TEXT_COLOR

	callR1     print_header,file_header

	setDispatchTable file_dispatch_table

file_in
	jsr        get_and_dispatch
	bcc        file_in
	clc
	rts
	             

;;; -------------------------------------------------------------------------------------
file_dispatch_table
	.word   file_new                ; F1
	.word   file_save               ; F3 - SAVE
	.word   0                       ; F5
	.word   0                       ; F7
	.word   file_load_program       ; F2
	.word   file_save_text          ; F4
	.word   0                       ; F6

;;; -------------------------------------------------------------------------------------
	.code
	
;;
;; View sub menu
;;
view_loop
	jsr     clear

view_in
	lda        orig_color
	sta        K_TEXT_COLOR

	callR1    print_header,view_header

	setDispatchTable view_dispatch_table

	jsr        get_and_dispatch
	bcc        view_in
	clc
	rts

;;; -------------------------------------------------------------------------------------
view_dispatch_table                
	.word   view_mem            ; F1
	.word   view_symbols        ; F3
	.word   0                   ; F5
	.word   0                   ; F7
	.word   view_user_screen    ; F2
	.word   0                   ; F4
	.word   0                   ; F6

view_mem
	jsr        gotoPrompt

	LoadW      r2,$ffff
	jsr        read_address_with_prompt

	bcs        :+                     ;; error 
	vgotoXY    HDR_COL,DATA_ROW
	ldx        input_hex_bank
	stx        BANK_CTRL_RAM
	jsr        mm_prt_block
:  
	rts

view_user_screen
	jsr     restore_user_screen
	callR1  wait_for_keypress,0
	clc
	kerjsr  SCRMOD
	cmp     #MODE_80_60
	beq     :+
	lda     #MODE_80_60
	sec
	kerjsr  SCRMOD
:
	jsr     clear
	rts

;;
;; View symbols in memory
;;
view_symbols
	jsr      clear_content

	lda      #DATA_ROW
	asl
	sta      r13L
	LoadW    r2,label_data_start

	pushBankVar   bank_meta_l
	
:
	lda     r13L
	
	cmp     #(LAST_ROW*2)
	beq     view_symbols_exit
	
	lsr
	sta     SCR_ROW
	
	bcc     @view_col_0
 
@view_col_1
	lda     #(HDR_COL + 25)
	bra     @view_symbol_continue

@view_col_0
	lda     #HDR_COL

@view_symbol_continue
	sta     SCR_COL
	jsr     vera_goto
	
	jsr     view_symbol_prt_line
	bcs     view_symbols_exit
	
	inc     r13L

	bra     :-

view_symbols_exit
	callR1 wait_for_keypress,0
	popBank

	rts

;;
;; Print the next symbol to the screen
;;
view_symbol_prt_line
	;; Grab string pointer
	ldy     #3
	lda     (r2),y
	sta     M1H
	dey
	lda     (r2),y
	dey
	sta     M1L
	ora     M1H
	beq     view_symbol_prt_line_done

	lda     #'$'
	jsr     vera_out_a

	;; grab value
	lda     (r2),y
	dey
	tax
	jsr     prthex

	lda     (r2),y
	tax
	jsr     prthex
	
	;; spacer
	lda     #' '
	jsr     vera_out_a
	lda     #' '
	jsr     vera_out_a

	;; print string symbol
	lda     M1H
	sta     r1H
	lda     M1L
	sta     r1L
	jsr     prtstr

	;; point to next
	lda     #4
	clc
	adc     r2L
	sta     r2L
	bcc     :+
	inc     r2H
:  
	clc
	rts

view_symbol_prt_line_done
	sec
	rts

;;
;; Asm sub menu
;;
asm_loop

@asm_in
	lda        orig_color
	sta        K_TEXT_COLOR

	callR1     print_header,asm_header

	jsr        main_display_core

	setDispatchTable asm_dispatch_table

	jsr        get_and_dispatch
	bcs        @asm_exit

	cmp        #CUR_DN
	bne        @assy_chk2
	jsr        assy_down
	bra        @asm_in
@assy_chk2

	cmp        #CUR_UP
	bne        @assy_chk3
	jsr        assy_up
@assy_chk3
	bra        @asm_in

@asm_exit
	clc
	rts

;;; -------------------------------------------------------------------------------------
	
asm_dispatch_table                
	.word   asm_addr      ; F1
	.word   asm_del_inst  ; F3
	.word   asm_add_label ; F5
	.word   0             ; F7
	.word   asm_add_inst  ; F2
	.word   asm_edit_inst ; F4
	.word   asm_del_label ; F6

;;; -------------------------------------------------------------------------------------
	.code
	
asm_addr
	LoadW   r2,$ffff
	jsr     read_address_with_prompt
	bcs     @asm_addr_exit
	lda     input_hex_bank
	sta     mem_last_bank
	lda     r0L
	sta     mem_last_addr
	sta     assy_selected_instruction
	lda     r0H
	sta     mem_last_addr+1
	sta     assy_selected_instruction+1


@asm_addr_exit
	;; Get rid of main page drivel.
	vgotoXY HDR_COL,DATA_ROW
	ldx     #ASSY_LAST_COL
	lda     screen_height
	sec
	sbc     #DATA_ROW
	tay
	jsr     erase_box
	rts

;;
;; Delete a label, then cause the asm display to redraw
;;
asm_del_label
	MoveW   assy_selected_instruction,r1
	jsr     meta_delete_label
	lda     #1
	jsr     set_dirty
	clc
	rts

;;
;; Add a label, then cause the asm display to redraw
;;
asm_add_label
	stz        input_string
	callR1R2   read_string_with_prompt,str_add_label_prompt,0
	LoadW      r1,input_string
	lda        input_string_length
	beq        :+
	
	MoveW      assy_selected_instruction,r2
	jsr        meta_add_label
	lda        #1
	jsr        set_dirty

:  
	clc
	rts

;;;
;;; Down, move to the next selected instruction
;;;
assy_down
	pushBankVar  bank_meta_l
	MoveW        meta_rgn_end,r3
	IncW         r3
	popBank
	
	MoveW      assy_selected_instruction,r1
	
	jsr        assy_down_first_bytecount

	;; If the new selected instruction is > region_end, do not scroll
	ifGE       r1,r3,@assy_down_exit
	
	ifEq16     r3,r1,@assy_down_no_scrollback
	PushW      r1
	MoveW      assy_selected_instruction,r1
	jsr        screen_add_scrollback_address
	PopW       r1
	MoveW      r1,assy_selected_instruction
	
@assy_down_no_scrollback
	
	;; Determine how many lines are needed
	jsr        assy_get_line_count
	sta        r13H
	
	;; Determine how many lines are available
	lda        #(ROW_LAST_INSTRUCTION-1)
	sec
	sbc        assy_selected_row ; How many line of next instruction are displayed 
	sta        r13L
	lda        r13H
	sec
	sbc        r13L              ; A == extra lines needed.
	beq        @assy_down_exit
	bpl        @assy_down_scroll_top_extra
@assy_down_exit 
	rts
	
	;; Extra scrolling needed
@assy_down_scroll_top_extra
	MoveW      mem_last_addr,r1
	jsr        assy_get_line_count
	sta        r13L
	jsr        assy_down_first_bytecount
	MoveW      r1,mem_last_addr
	
	sec
	lda        r13H 
	sbc        r13L
	sta        r13H
	beq        @assy_down_scroll_exit
	bpl        @assy_down_scroll_top_extra

@assy_down_scroll_exit
	rts
	
;;
;; Get line count for instruction @r1
;; Input r1 - Ptr to instruction for query
;; Output A - number of lines
;; TODO: Fix find_label to protect r1
assy_get_line_count
	PushW       r1
	jsr         meta_find_label
	beq         @assy_get_line_count_label
	PopW        r1
	lda         #1
	rts

@assy_get_line_count_label
	PopW        r1
	lda         #3
	rts

;;
;; Move r1 down by the bytecount of instruction @r1
;; TODO: Fix get_byte_count to preserve r1, then remove push/pop from here.
;;
assy_down_first_bytecount
	PushW      r1
	jsr        decode_get_byte_count
	tax

	PopW       r1
	txa

	clc
	adc        r1L
	sta        r1L
	bcc        :+
	inc        r1H
:  
	rts
	
;;
;; Up, move to the previous instruction
;;
assy_up
	MoveW      assy_selected_instruction,r1

	jsr        screen_get_prev_scrollback_address
	bcs        @assy_up_exit

	MoveW      mem_last_addr,TMP1
	ifGE       r0,TMP1,@assy_up_continue

	;; Update first address too, e.g. scroll up
	MoveW      r0,mem_last_addr

@assy_up_continue
	;; Set previous address
	MoveW      r0,assy_selected_instruction

@assy_up_exit
	rts

;;
;; Add an instruction
;;
asm_add_inst
	lda        assy_selected_row
	cmp        #$ff
	bne        :+
	jmp        @asm_add_inst_exit

:
	sta        SCR_ROW
	lda        #HDR_COL
	sta        SCR_COL
	vgoto

	ldx        #49
	ldy        #3
	sec
	jsr        draw_box

	lda        assy_selected_row
	inc
	sta        SCR_ROW
	lda        #HDR_COL+2
	sta        SCR_COL
	vgoto
	
	jsr        read_string
	bcc        @asm_add_continue
	clc
	rts

@asm_add_continue   
	LoadW      r2,tmp_string_stash
	pushBankVar bank_assy
	jsr        util_strcpy
	popBank

	;; Encode once, to get the byte count
	lda        #1
	sta        encode_dry_run
	MoveW      assy_selected_instruction,encode_pc
	LoadW      r1,input_string
	jsr        encode_string
	
	bcc        :+
	jmp        @asm_add_inst_fail
	             
:  
	lda        encode_buffer_size
	bne        @asm_add_inst_continue

@asm_add_inst_fail
	LoadW      ERR_MSG,str_syntax_fail
	lda        #1
	clc                
	rts

@asm_add_inst_continue
	ldx        encode_buffer_size                   ; # of bytes
	MoveW      assy_selected_instruction,r1

	jsr        screen_add_scrollback_address

	jsr        edit_insert
	
	;; Encode a second time, so relocated labels are used, use the stashed string
	;; (e.g. unmodified by the first encode_string call)
	LoadW      r1,tmp_string_stash
	LoadW      r2,input_string
	pushBankVar  bank_assy
	jsr        util_strcpy
	popBank
	
	stz        encode_dry_run
	MoveW      assy_selected_instruction,encode_pc
	LoadW      r1,input_string
	jsr        encode_string
	
	jsr        asm_apply_encoding

@asm_add_inst_exit
	;; Bump selected address
	lda     encode_buffer_size
	clc
	adc     assy_selected_instruction
	sta     assy_selected_instruction
	bcc     :+
	inc     assy_selected_instruction+1
:  
	;; Indicate success
	lda     #1
	jsr     set_dirty
	clc
	rts


;;
;; Delete an instruction
;;
asm_del_inst
	lda        assy_selected_row
	cmp        #$ff
	beq        @asm_del_inst_exit

	;; delete the instructions
	MoveW      assy_selected_instruction,r1
	PushW      r1

	jsr        decode_get_byte_count
	tax

;                jsr        screen_scrollback_truncate
;                TODO something for delete here
	             
	PopW       r1
	jsr        edit_delete

	;; If user deleted the last instruction, make sure the last selected instruction is still the last
	pushBankVar bank_meta_l
	MoveW      meta_rgn_end,r5
	popBank

	ifGE       r5,assy_selected_instruction,@asm_del_inst_exit
	MoveW      r5,assy_selected_instruction

@asm_del_inst_exit
	lda        #1
	jsr        set_dirty
	clc
	rts


;;;
;;; Edit, in place, the currently selected instruction
;;; 
asm_edit_inst
	stz        decoded_str_next
	MoveW      assy_selected_instruction,r1
	
	jsr        decode_get_byte_count
	pha             ; Save byte count for later

	MoveW      assy_selected_instruction,r1
	jsr        decode_next_instruction
	
	lda        #' '
	jsr        decode_push_char
	
	MoveW      assy_selected_instruction,r2
	
	jsr        decode_append_next_argument
	jsr        decode_terminate
	LoadW      r1,decoded_str
	jsr        util_trim_string

	callR1R2   read_string_with_prompt,str_empty,decoded_str
	bcc        @asm_edit_inst_accept
	pla
	jmp        @asm_edit_inst_exit

@asm_edit_inst_accept
	;; Attempt encoding, if byte count is exactly the same as old, no edit is needed
	lda        #1
	sta        encode_dry_run
	MoveW      assy_selected_instruction,encode_pc
	LoadW      r1,input_string
	jsr        util_trim_string

	LoadW      r2,decoded_str
	jsr        util_strcpy ; stash the newly editing string for the second pass
	jsr        encode_string
	bcc        @asm_edit_no_error1
	jmp        @asm_edit_inst_error
	
@asm_edit_no_error1
	;; Setup r1 for shorten/lengthen code
	MoveW      assy_selected_instruction,r1

	pla             ; Get old code byte count
	sta        r11L
	lda        encode_buffer_size
	sec
	sbc        r11L
	beq        @asm_edit_replace_code
	
	;; Alter the space. If new instruction is less, delete enough bytes to account for change
	;; If the new insrtuction is more, add enough bytes. Both operations leave first byte alone,
	;; to preserve any labels involved. A == difference
	bmi        @asm_edit_shorten_code
	
@asm_edit_lengthen_code
	IncW       r1
	tax
	jsr        edit_insert
	bra        @asm_edit_replace_code
	
@asm_edit_shorten_code
	ldx        r11L
	jsr        meta_delete_expr

	IncW       r1
	txa        ; Orig byte count into A
	sbc        encode_buffer_size
	tax        ; Bytes needed to shorten the code.
	jsr        edit_delete
	             
@asm_edit_replace_code
	;; There are exactly the needed bytes at the edit point, just replace the bytes from the encode pass
	;; Do same as insert_inst now
	stz        encode_dry_run ; Turns encode into full encode pass
	LoadW      r1,decoded_str
	jsr        encode_string

	jsr        asm_apply_encoding

@asm_edit_inst_exit
	lda        #1
	jsr        set_dirty

	clc
	rts

@asm_edit_inst_error
	LoadW      ERR_MSG,str_syntax_fail
	pla
	clc                
	rts

;;
;; Apply encoding - copy encode buffer to insert point
;;
asm_apply_encoding
	;; Copy contents of encode buffer into destination location
	LoadW      r1,encode_buffer
	MoveW      assy_selected_instruction,r2
	ldy        encode_buffer_size
	dey
@asm_apply_encoding_loop
	lda        (r1),y
	sta        (r2),y
	dey
	bpl        @asm_apply_encoding_loop
	rts
	
;;
;; Watch sub menu
;;
watch_loop
	jsr     clear

watch_in
	lda        orig_color
	sta        K_TEXT_COLOR

	callR1     print_header,watch_header

	jsr        assy_display_sidebar

	setDispatchTable watch_dispatch_table

	jsr        get_and_dispatch
	bcs        watch_exit

	cmp        #DELETE
	bne        :+
	jsr        watch_select_del
	bra        watch_in
:  
	cmp        #CURSOR_DN
	bne        :+
	jsr        watch_select_dn
	bra        watch_in
:  
	cmp        #CURSOR_UP
	bne        watch_in
	jsr        watch_select_up
	bra        watch_in

watch_exit
	pushBankVar bank_assy
	lda        #WATCH_NON_HIGHLIGHT
	sta        watch_highlight
	popBank
	clc
	rts

;;; -------------------------------------------------------------------------------------
watch_dispatch_table                
	.word   watch_byte       ; F1
	.word   watch_cstr       ; F3
	.word   0                ; F5
	.word   0                ; F7
	.word   watch_word       ; F2
	.word   watch_pstr       ; F4
	.word   watch_select_del ; F6

;;; -------------------------------------------------------------------------------------
	.code
	
watch_byte
	lda     #WATCH_BYTE
	jsr     assy_watch
	rts

watch_word
	lda     #WATCH_WORD
	jsr     assy_watch
	rts

watch_cstr
	lda     #WATCH_CSTR
	jsr     assy_watch
	rts

watch_pstr
	lda     #WATCH_PSTR
	jsr     assy_watch
	rts

;; -----
watch_select_dn
	pushBankVar bank_assy
	lda     watch_highlight
	clc
	adc     #WATCH_ENTRY_SIZE
	cmp     watch_counter
	bmi     watch_select_dn_exit
	lda     #0

watch_select_dn_exit
	sta     watch_highlight
	popBank
	rts

;; -----
watch_select_up
	pushBankVar bank_assy
	lda     watch_highlight
	sec
	sbc     #WATCH_ENTRY_SIZE
	bpl     watch_select_up_exit
	;; cycle to the end
	lda     watch_counter
	lsr
	lsr
	dec
	asl
	asl

watch_select_up_exit
	sta     watch_highlight
	popBank
	rts

;; -----
;; Delete the entry pointed at by r1, then move remaining entries up
watch_select_del
	pushBankVar bank_assy
	PushW   r2

	;; R1 points to the deleted entry
	lda     #>watch_start
	sta     r1H
	sta     r2H

	lda     #<watch_start
	clc
	adc     watch_highlight
	sta     r1L
	bcc     :+
	inc     r1H
:  

	clc
	adc     #WATCH_ENTRY_SIZE
	sta     r2L
	bcc     :+
	inc     r2H
:  

	lda     watch_counter
	sec
	sbc     watch_highlight
	tax
	ldy     #0
watch_select_del_loop
	lda     (r2),y
	sta     (r1),y
	iny
	dex
	bpl     watch_select_del_loop

	lda     #WATCH_NON_HIGHLIGHT
	sta     watch_highlight

	PopW    r2
	popBank
	
	;; Erase the contents of the watch box so it properly refreshes after delete

	vgotoXY  WATCH_COL+1,WATCH_ROW+2
	ldx      #WATCH_BOX_WIDTH-2
	ldy      #WATCH_BOX_HEIGHT-2
	jsr      erase_box
	
	rts
	
;
;; Memory mode methods
;;

;;
;; Print memory block hex
;; Input - Memory address ZP r2
;; Side effects - Clobbers A,Y
;;
mm_prt_block
	lda     #COLOR_CDR_MEM
	jsr     screen_set_fg_color

	lda     screen_row_data_count
	sta     r3L

@mm_prt_bl_loop 
	;; -- Print a single row 
	ldx     r2H
	jsr     prthex
	ldx     r2L
	jsr     prthex

	charOut  CHR_SPACE
	
	lda     #MEM_NUMBER_OF_BYTES
	jsr     prthexbytes

	lda     #CHR_SPACE
	jsr      vera_out_a

	lda     #MEM_NUMBER_OF_BYTES
	jsr     prtxlatedcodes

	;; -- Done printing a single row

	lda     r2L
	clc
	adc     #MEM_NUMBER_OF_BYTES
	sta     r2L
	bcc     @mm_prt_block_no_carry
	lda     r2H
	adc     #0
	sta     r2H
@mm_prt_block_no_carry
	lda     #HDR_COL
	sta     SCR_COL
	inc     SCR_ROW
	vgoto
	dec     r3L
	lda     r3L
	bne     @mm_prt_bl_loop
@mm_prt_bl_done rts


;;
;; Wait for a key press
;;
wait_for_keypress
	ldx      #HDR_COL
	ldy      #58
	lda      r1L
	ora      r1H
	beq      :+
	jsr      prtstr_at_xy
:  
	kerjsr   GETIN
	beq      wait_for_keypress
	rts
	
;; 
;; Assembly run
;; Get execution address and run at that address
;;
assy_run
	;; Preload the input string with the exec address
	LoadW      r10,input_string
	stz        decoded_str_next
	
	pushBankVar bank_meta_l
	lda        meta_exec_addr
	sta        r2L
	lda        meta_exec_addr+1
	sta        r2H
	popBank
	
	callR1     rdhex2,str_addr_prompt        ;; r2 has preload value already
	bcs        @assy_run_abort
	beq        @assy_run_exit
	
@assy_run_ok
	jmp        (r2)
	rts                    ; not likely to return from here. Target returns to dispatch

@assy_run_abort
	LoadW      ERR_MSG,str_bad_address
@assy_run_exit	
	sec
	rts                    ; return dispatch

;;
;; Assembly watch
;; Add a watch address.
;; Uses r1 to scan watch list.
;; Input A - Type of entry
;; Clobbers A,Y
;; Output r1 - Pointing to the watch entry in the table
;;
assy_watch
	sta     r5L

	pushBankVar bank_assy
	lda     watch_counter
	cmp     #WATCH_BYTE_COUNT
	bmi     assy_watch_not_full
	popBank
	rts

assy_watch_not_full
	lda     #<watch_start
	sta     r1L
	lda     #>watch_start
	sta     r1H

	ldy     #0
assy_watch_loop
	lda     (r1),y                  ; watch type
	beq     assy_watch_add

	iny                             ; skip this entry 
	iny                             ; skip this bank
	iny                             ; skip the address
	iny                             ; skip the address

	tya     
	bra     assy_watch_loop

assy_watch_add
	;; Save r1 & Y so it doesn't get trashed by printing
	PushW   r1
	phy
	LoadW   r2,$ffff
	jsr     read_address_with_prompt

	bcc     assy_watch_addr_ok

	;; discard saved r1 and Y values, no longer needed
	pla
	pla
	pla
	popBank
	rts
	
assy_watch_addr_ok
	;; Restore r1 to point back at a watch variable
	ply
	PopW    r2

	;; R1+y pointing at address of watch entry
	lda     r5L                ; Save type
	sta     (r2),y
	iny

	lda     input_hex_bank     ; Save bank
	sta     (r2),y
	iny

	lda     r0L
	sta     (r2),y             ; Save addr lsb
	iny

	lda     r0H
	sta     (r2),y             ; Save addr msb

	sty     watch_counter

	jsr     gotoPrompt
	ldx     #(ASSY_LAST_COL-1)
	jsr     prtspaceto

assy_watch_exit
	popBank
	rts

;;
;; Assembly mode method
;;
;; Print code block hex
;; Input - Memory address ZP r2
;; Side effects - Clobbers A,Y, r2
;;
;; r2 used to point to each instruction in turn.
;;
assy_prt_block
	stz      print_to_file

	lda      #$ff
	sta      assy_selected_row
	
	vgotoXY 0, DATA_ROW

	lda     screen_row_data_count  ; Number of lines to print
	sta     r3L

	MoveW   mem_last_addr,r2

@assy_prt_bl_loop
	ifEq16  r2,assy_selected_instruction,@assy_prt_selected
	
@assy_prt_normal
	lda     orig_color
	pha
	bra     @assy_prt
	
@assy_prt_selected
	lda     orig_color
	pha
	and     #$0F
	ora     #(COLOR_CDR_BACK_HIGHLIGHT<<4)
	sta     orig_color
	sta     K_TEXT_COLOR

@assy_prt
	jsr     assy_prt_inst          ; Also increments r2
	pla
	sta     orig_color

	stz     SCR_COL
	inc     SCR_ROW
	vgoto

	lda     screen_last_row
	cmp     SCR_ROW
	bmi     @assy_prt_bl_done

	;; TODO: Hoist this out of the prt_block loop?
	pushBankVar bank_meta_l
	MoveW   meta_rgn_end,M1
	IncW    M1
	popBank
	
	ifGE    r2,M1,@assy_prt_bl_done
	
@assy_prt_bl_incr
	dec     r3L
	lda     r3L
	cmp     #0
	bne     @assy_prt_bl_loop

@assy_prt_bl_done
	;;  todo COLOR_CDR_BACK
@assy_prt_bl_clear_rest
	lda      orig_color
	sta      K_TEXT_COLOR
	
	stz      SCR_COL
	jsr      vera_goto
	ldx      #ASSY_LAST_COL
	ldy      #(ROW_MAX + 1)
	sec
	jsr      erase_box

	jsr      assy_display_sidebar

	rts

;;
;; Display registers
;;
assy_display_registers
	lda     orig_color
	sta     K_TEXT_COLOR
	
	pushBankVar bank_assy
	vgotoXY SIDE_BAR_X,PSR_ROW
	ldx     #PSR_BOX_WIDTH
	ldy     #PSR_BOX_HEIGHT 
	clc
	jsr     draw_box
	
	ldx     #(ASSY_LAST_COL+1)
	ldy     #(PSR_ROW+1)
	callR1  prtstr_at_xy,str_register_psr

	;; Display psr
	inc     SCR_ROW
	lda     #ASSY_LAST_COL+2
	sta     SCR_COL
	jsr     vera_goto

	lda     brk_data_valid
	beq     @dr_pc
	
	ldx     #8
	lda     brk_data_psr
@dr_psr_loop
	asl
	pha
	bcc     @dr_psr_zero
	lda     #'1'
	bra     :+
@dr_psr_zero
	lda     #'0'
:  
	cpx     #5
	beq     @dr_psr_skip
	cpx     #6
	beq     @dr_psr_skip
	jsr     vera_out_a
	lda     #CHR_SPACE
	jsr     vera_out_a
@dr_psr_skip
	pla
	dex
	bne     @dr_psr_loop

	;; Do other registers

@dr_pc
	ldx     #ASSY_LAST_COL+1
	ldy     SCR_ROW
	iny
	iny
	callR1  prtstr_at_xy,str_register_pc
	lda     brk_data_valid
	beq     @dr_a
	ldx     brk_data_pc+1
	jsr     prthex
	ldx     brk_data_pc
	jsr     prthex

@dr_a
	ldx     #ASSY_LAST_COL+1
	ldy     SCR_ROW
	iny
	iny
	jsr     vera_goto_xy
	callR1  prtstr,str_register_a
	lda     brk_data_valid
	beq     @dr_x
	ldx     brk_data_a
	jsr     prthex

@dr_x
	ldx     #ASSY_LAST_COL+1
	ldy     SCR_ROW
	iny
	iny
	callR1  prtstr_at_xy,str_register_x
	lda     brk_data_valid
	beq     @dr_y
	ldx     brk_data_x
	jsr     prthex

@dr_y
	ldx     #ASSY_LAST_COL+1
	ldy     SCR_ROW
	iny
	iny
	callR1  prtstr_at_xy,str_register_y
	lda     brk_data_valid
	beq     @dr_sp
	ldx     brk_data_y
	jsr     prthex

@dr_sp
	ldx     #ASSY_LAST_COL+1
	ldy     SCR_ROW
	iny
	iny
	callR1  prtstr_at_xy,str_register_sp
	lda     brk_data_valid
	beq     @dr_exit
	ldx     #$01
	jsr     prthex
	ldx     brk_data_sp
	jsr     prthex

@dr_exit
	popBank
	rts

;;
;; Display the sidebar with the appropriate sidebar elements
;;
assy_display_sidebar
	jsr     assy_display_registers
	jsr     assy_display_watches
	jsr     assy_display_zp_registers
	jsr     assy_display_stack
	jsr     assy_display_vera
	rts

;;	
;;	Display saved VERA information
;;	
assy_display_vera
	lda      orig_color
	sta      K_TEXT_COLOR

	vgotoXY  VERA_COL,VERA_ROW
	ldx      #VERA_BOX_WIDTH
	ldy      #VERA_BOX_HEIGHT
	jsr      draw_box
	
	ldx      #(VERA_COL+2)
	ldy      #(VERA_ROW+1)
	callR1   prtstr_at_xy,str_vera
	rts

;;
;; Display watch locations
;;
assy_display_watches
	lda      orig_color
	sta      K_TEXT_COLOR

	vgotoXY  WATCH_COL,WATCH_ROW
	ldx      #WATCH_BOX_WIDTH
	ldy      #WATCH_BOX_HEIGHT
	jsr      draw_box

	ldx      #(WATCH_COL+1)
	ldy      #(WATCH_ROW+2)
	callR1   prtstr_at_xy,str_watch_locations

	pushBankVar bank_assy
	
	stz      watch_counter
	
assy_display_watch_loop
	LoadW    r1,watch_start
	ldy      watch_counter

	;; Get watch type
	lda      (r1),y
	bne      :+
	jmp      assy_display_watch_exit

:
	sta      r3L    
	iny

	;; Get bank
	lda      (r1),y
	tax
	iny

	;; Get address
	lda      (r1),y
	sta      r2L
	iny
	lda      (r1),y
	sta      r2H

	ora      r2L
	cmp      #0
	bne      assy_display_watches_valid
	jmp      assy_display_watches_incr
	
	lda      orig_color
	sta      K_TEXT_COLOR

assy_display_watches_valid

	tya
	dec
	dec
	dec

	cmp      watch_highlight
	bne      :+
	
	lda      orig_color
	and      #$0F
	ora      #(COLOR_CDR_BACK_HIGHLIGHT<<4)
	sta      K_TEXT_COLOR
	
:  
	lda      #(ASSY_LAST_COL+2)
	sta      SCR_COL
	inc      SCR_ROW
	vgoto

	pushBankX
	
	MoveW   r2,r1
	txa
	jsr      assy_print_banked_address
	
	inc      SCR_COL
	vgoto

	lda      r3L
	cmp      #WATCH_BYTE
	beq      assy_display_watch_byte

	cmp      #WATCH_PSTR
	beq      assy_display_watch_pstr

	cmp      #WATCH_CSTR
	beq      assy_display_watch_cstr

assy_display_watch_word
	lda      #SCR_DOLLAR
	jsr      vera_out_a

	ldy      #1
	lda      (r2),y
	tax
	jsr      prthex

	ldy      #0
	lda      (r2),y
	tax
	jsr      prthex
	bra      assy_display_watches_incr

assy_display_watch_byte
	lda      #SCR_DOLLAR
	jsr      vera_out_a

	ldy      #0
	lda      (r2),y
	tax
	jsr      prthex

	bra      assy_display_watches_incr

assy_display_watch_cstr
	ldy      #0
assy_display_watch_cstr_loop
	lda      (r2),y
	beq      assy_display_watches_incr
	jsr      petscii_to_scr
	jsr      vera_out_a
	iny
	lda      SCR_COL
	cmp      #78
	bpl      assy_display_watches_incr
	bra      assy_display_watch_cstr_loop

assy_display_watch_pstr
	lda   (r2)
	inc
	sta   r3L
	ldy   #1
assy_display_watch_pstr_loop
	lda   (r2),y
	jsr   petscii_to_scr
	jsr   vera_out_a
	iny
	lda   SCR_COL
	cmp   #78
	bpl   :+
	tya
	cmp   r3L
	bne   assy_display_watch_pstr_loop
:
	bra   assy_display_watches_incr

assy_display_watches_incr
	lda      orig_color
	sta      K_TEXT_COLOR

	popBank
	lda      watch_counter
	clc
	adc      #WATCH_ENTRY_SIZE
	sta      watch_counter
	cmp      #WATCH_BYTE_COUNT
	bpl      assy_display_watch_exit
	jmp      assy_display_watch_loop

assy_display_watch_exit
	popBank
	rts

;;
;; Display the zero page registers
;;
assy_display_zp_registers
	lda      orig_color
	sta      K_TEXT_COLOR
	
	vgotoXY  REGISTER_COL,REGISTER_ROW
	ldx      #DBG2_BOX_WIDTH
	ldy      #REGISTER_BOX_HEIGHT
	clc
	jsr      draw_box
	ldx      #(REGISTER_COL+1)
	ldy      #(REGISTER_ROW+1)
	callR1   prtstr_at_xy,str_zp_registers
	
	lda      #REGISTER_ROW+3+15 ; +4, below label, + 15 is for 15 registers
	sta      SCR_ROW

	ldx      #15
	lda      #$15 ; Note different than $15! Using BCD for register label
	sta      r11L
@assy_display_zp_registers_loop
	lda      #(REGISTER_COL+2)
	sta      SCR_COL
	jsr      vera_goto
	charOut  SCR_R
	
	lda      r11L
	and      #$F0
	beq      @assy_display_zp_registers_skip_tens
	lsr
	lsr
	lsr
	lsr
	clc
	adc      #SCR_ZERO
	charOutA
	
@assy_display_zp_registers_skip_tens
	lda      r11L
	and      #$0F
	clc
	adc      #SCR_ZERO
	charOutA
	
	charOut  SCR_SPACE
	lda      r11L
	cmp      #$10 ; Still works, even though r11L is BCD
	bpl      @assy_display_zp_registers_skip_extra_space
	charOut  ' '

@assy_display_zp_registers_skip_extra_space   
	;; Get and display the saved values (not the current actual ones)

	LoadW    r0,reg_save
	phx
	txa
	asl
	tay
	iny
	
	pushBankVar bank_assy
	lda      (r0),y
	sta      r1H
	dey
	lda      (r0),y
	sta      r1L
	
	ldx      brk_data_valid
	beq      :+
	
	stz      decoded_str_next
	jsr      decode_push_hex_word
	jsr      decode_terminate
	callR1   prtstr,decoded_str
	
:  
	popBank
	
	plx
	
@assy_display_zp_registers_incr	
	;; Decrement for the next register
	sed
	lda      r11L
	sec
	sbc      #1
	sta      r11L
	cld

	dec      SCR_ROW
	dex      
	bmi      @assy_display_zp_registers_exit
	jmp      @assy_display_zp_registers_loop
@assy_display_zp_registers_exit
	rts

;;
;; Display the stack
;;
assy_display_stack
	lda     orig_color
	sta     K_TEXT_COLOR
	
	vgotoXY  STACK_COL,STACK_ROW
	ldx      #DBG2_BOX_WIDTH
	ldy      #STACK_BOX_HEIGHT
	clc
	jsr      draw_box
	ldx      #(STACK_COL+1)
	ldy      #(STACK_ROW+1)
	callR1   prtstr_at_xy,str_stack

	;; r2 points to top of stack
	pushBankVar bank_assy
	
	lda      brk_data_valid
	beq      @assy_display_stack_exit

	lda      #$01
	sta      r2H
	lda      brk_data_sp
	inc
	sta      r2L
	
	lda      #(STACK_ROW+3)
	sta      SCR_ROW
	
@assy_display_stack_loop
	lda      #(ASSY_LAST_COL+DBG_BOX_WIDTH+2)
	sta      SCR_COL
	jsr      vera_goto
	
	MoveW    r2,r1
	stz      decoded_str_next
	jsr      decode_push_hex_word
	
	lda      #' '
	jsr      decode_push_char
	
	lda      (r2)
	jsr      decode_push_hex

@assy_display_stack_skip
	LoadW    r1,decoded_str
	jsr      decode_terminate
	jsr      prtstr

	inc      r2L
	beq      @assy_display_stack_exit

	inc      SCR_ROW
	lda      SCR_ROW
	cmp      #(STACK_BOX_HEIGHT + STACK_ROW - 2)
	bmi      @assy_display_stack_loop
	
@assy_display_stack_exit
	popBank
	rts

;;
;; Print a banked address
;; Input r1 - address
;;        A - bank
;;
assy_print_banked_address
	pha
	
	lda      #SCR_DOLLAR
	jsr      vera_out_a

	plx
	beq      @assy_display_no_bank

	jsr      prthex
	bra      @assy_display_prt_address

@assy_display_no_bank
	charOut ' '
	charOut ' '

@assy_display_prt_address
	lda     #':'
	jsr      vera_out_a

	;; print address
	ldx      r1H
	jsr      prthex

	ldx      r1L
	jsr      prthex

	rts

;;
;; Print instruction line with detail
;; Input - Memory address ZP r2
;; Side effects - Clobbers A,X,Y
;;
assy_prt_inst 
	MoveW   r2,r1
	jsr     meta_find_label
	bne     assy_prt_inst_check

assy_prt_inst_label
	;; Make an empty line before the label, readability
	stz     SCR_COL
	vgoto
	ldx     #ASSY_LAST_COL
	jsr     prtspaceto

	jsr     assy_prt_check_continue
	bcc     :+
	rts                             ; beyond last line permissable
	
:
	lda     #COLOR_CDR_LABEL
	jsr     screen_set_fg_color

	jsr     assy_prt_check_continue
	bcc     assy_actually_print_label
	rts

assy_actually_print_label
	inc     SCR_ROW
	stz     SCR_COL
	vgoto

	ldx     #COL_INST_BYTES
	jsr     prtspaceto              ; relying on the fact that r1 is left alone.

	jsr     meta_print_banked_label

	ldx     #ASSY_LAST_COL
	jsr     prtspaceto

	stz     SCR_COL
	inc     SCR_ROW
	vgoto

assy_prt_inst_check
	jsr     assy_prt_check_continue
	bcc     :+
	rts
	
:
	lda     orig_color
	sta     K_TEXT_COLOR 

	ldx     #2
	jsr     prtspaceto

	ldx     #COLOR_CDR_ADDR
	jsr     screen_set_fg_color

	ldx     r2H            ; Print address first
	jsr     prthex
	ldx     r2L
	jsr     prthex

	ldx     #COL_INST_BYTES
	jsr     prtspaceto

	MoveW   r2,r1
	jsr     decode_get_byte_count
	cmp     #4
	bmi     @assy_prt_inst_3_bytes
	;; This is likely CSTR or PSTR
	lda     #3
@assy_prt_inst_3_bytes	
	jsr     prthexbytes

	lda     #COLOR_CDR_BYTES
	jsr     screen_set_fg_color

	ldx     #COL_INSTRUCTION
	jsr     prtspaceto

	MoveW   r2,r1
	jsr     decode_next_instruction
	jsr     decode_terminate
	lda     #COLOR_CDR_INST
	jsr     screen_set_fg_color
	callR1  prtstr,decoded_str

	ldx     #COL_ARGUMENTS
	jsr     prtspaceto

	lda     #COLOR_CDR_ARGS
	jsr     screen_set_fg_color
	stz     decoded_str_next
	jsr     decode_next_argument
	callR1  prtstr_shim,decoded_str

	MoveW   r2,r1
	jsr     decode_get_byte_count
	clc
	adc     r2L
	sta     r2L
	bcc     :+
	inc     r2H
:  

	ldx     #ASSY_LAST_COL
	jsr     prtspaceto
	rts


;;
;; Check to see if the last line has been reached. 
;; Output CC - OK to continue
;;        CS - Not OK, exit print
;;
assy_prt_check_continue
	ifNe16  r2,assy_selected_instruction,@assy_prt_chk_continue2
	lda     SCR_ROW
	sta     assy_selected_row
	
@assy_prt_chk_continue2
	lda     SCR_ROW
	cmp     screen_last_row
	bmi     :+
	sec
	rts
:  
	clc
	rts

;; ------------------------------------------------------------------------------------------

;;
;; Read the hex address (plus optional bank) and set values as needed
;;
;; Input r2 - Preload value
;; Output in r0 - Ptr to input_hex_value
;; Carry set == error
;;
read_address_with_prompt
	callR1     rdhex2,str_addr_prompt
	bne        @read_addr_ok

	LoadW      ERR_MSG,str_bad_address
	sec
	rts

@read_addr_ok
	MoveW      input_hex_value,r0
	jsr        gotoPrompt
	ldx        #(ASSY_LAST_COL-1)
	jsr        prtspaceto

	clc
	rts

;;
;; print_header
;; Print the F1 F3, etc header, with labels
;;
print_header
	PushW   r1

	ldx     #HDR_COL
	ldy     #HDR_ROW
	callR1  prtstr_at_xy,fn_header

	ldx     BANK_CTRL_RAM
	jsr     prthex

	ldx     #0
	ldy     SCR_ROW
	iny                             ; Save a byte, vera_goto will store in SCR_COL, SCR_ROW

	PopW    r1
	jsr     prtstr_at_xy            ; r1 has sub header from caller

	lda     #50
	sta     SCR_COL
	jsr     vera_goto
	callR1  prtstr,str_region_start
	jsr     meta_get_region
	ldx     r0H
	jsr     prthex
	ldx     r0L
	jsr     prthex
	
	charOut ','
	charOut '$'

	ldx     r1H
	jsr     prthex
	ldx     r1L
	jsr     prthex
	
	callR1       prtstr,str_region_end

	lda     orig_color
	sta     K_TEXT_COLOR
	jsr     print_horizontal_line
	rts

	.ifdef DEV
;;
;; Print logo at current X-Y
;; Current logo is 7w x 7h
;;
print_logo
	lda     SCR_COL
	pha

	LoadW   r1,logo2_buffer

	ldy     #7
print_logo_row_loop
	pla
	pha
	sta     SCR_COL

	phx
	phy
	vgoto
	ply
	plx

	ldx     #7
	lda     (r1)            ; get color
	jsr     screen_set_fg_color
	IncW    R1

print_logo_col_loop
	lda     (r1) 
	charOutA
	IncW    r1

	dex
	bne     print_logo_col_loop

	inc     SCR_ROW
	dey
	bne     print_logo_row_loop

	pla
	rts

;;; -------------------------------------------------------------------------------------
;; Strings and display things

	;; Logo buffer, first byte of each line is color
	;; each succeeding byte is the shape character. 
	;; draw routine needs to maintain the color for the entire line.

logo2_buffer
	.byte $64, $df,$20,$20,$20,$20,$20,$e9
	.byte $6e, $f4,$df,$20,$20,$20,$e9,$e7
	.byte $63, $f5,$a0,$df,$20,$e9,$a0,$f6
	.byte $65, $20,$77,$fb,$20,$ec,$77,$20
	.byte $67, $20,$6f,$fe,$20,$fc,$6f,$20
	.byte $68, $67,$a0,$69,$20,$5f,$a0,$74
	.byte $62, $76,$69,$20,$20,$20,$5f,$75

	.endif
	
fn_header            .byte " F1   F2   F3   F4   F5    F6    F7   F8         HI MEMORY = ", 0
main_header          .byte " FILE VIEW ASM  RUN              WATC EXIT", 0
break_header         .byte "      VIEW      CONT STEP  STIN  WATC STOP", 0
file_header          .byte " NEW  LOAD SAVE TEXT                  BACK", 0
view_header          .byte " MEM  SCRN  SYMB                      BACK", 0
asm_header           .byte " ADDR +INS -INS EDIT +LAB -LAB        BACK", 0
watch_header         .byte " BYTE WORD CSTR PSTR        DEL       BACK", 0


str_addr_prompt      .byte "ADDRESS: ", 0
str_bad_address      .byte "BAD ADDRESS VALUE", 0
filename_prompt      .byte "FNAME: ", 0
str_main_label       .byte "MAIN", 0
str_add_label_prompt .byte "NEW LABEL: ", 0

version_string       .byte "CODEX ASSEMBLY ENVIRONMENT V0.90", CR
	.ifdef DEV
rls_090_0            .byte "                 ", SCR_BULLET, " ROM'ED", CR
rls_090_1            .byte "                 ", SCR_BULLET, " SIZE TRIM", CR
rls_090_2            .byte "                 ", SCR_BULLET, " EXTERN DECOMPILE", 0
	.else
	                  .byte 0
	.endif

str_press_2_continue .byte "PRESS A KEY TO CONTINUE...", 0
str_loading_pgm      .byte "LOADING PROGRAM: ", 0
str_loading_dbg      .byte "LOADING .DBG", 0
str_loading_dbi      .byte ", .DBI", 0
str_loading_done     .byte "SUCCESSFUL LOAD", 0
str_saving_pgm       .byte "SAVING PROGRAM: ",0
str_saving_dbg       .byte "SAVING DEBUG  : ", 0
str_ext_dbg          .byte ".DBG", 0
str_ext_dbi          .byte ".DBI", 0
str_ext_txt          .byte ".TXT", 0
str_watch_locations  .byte "WATCH LOCATIONS", 0
str_zp_registers     .byte "REGISTERS", 0
str_stack            .byte "STACK", 0
str_vera             .byte "DISPLAY", 0
str_register_psr     .byte " N V D I Z C", 0
str_register_pc      .byte " PC  ", 0
str_register_a       .byte " A   ", 0
str_register_x       .byte " X   ", 0
str_register_y       .byte " Y   ", 0 
str_register_sp      .byte " SP  ", 0
str_syntax_fail      .byte "INVALID SYNTAX", 0
str_region_start     .byte "PRGM REGION[$", 0
str_region_end       .byte "]", CR, 0
str_empty            .byte 0

	.ifdef DEV
str_65c02_required   .byte "ERROR: 65C02 CPU REQUIRED!", CR, 0
	.endif

;;; -------------------------------------------------------------------------------------
	.code
	

;;
;; Reset the VERA so the blinking cursor doesn't leave a trail on the screen!
;;
reset_vera_for_exit
	lda     #$00                    ; turn off increment
	sta     VERA_ADDR_HI

	lda     VERA_ADDR_MID
	clc
	adc     #1                      ; Go to next row
	sta     VERA_ADDR_MID
	
	stz     VERA_ADDR_LO            ; Start on column 0

	rts

;;
;; New program
;;
	RTS_INSTRUCTION=$60
file_new
	pushBankVar bank_assy
	stz         orig_file_name
	popBank

	jsr     clear_program_settings
	LoadW   r2,$ffff
	jsr     read_address_with_prompt

	bcs     @file_new_exit
	
	lda     r0L
	sta     r1L
	sta     mem_last_addr
	sta     assy_selected_instruction
	
	lda     r0H
	sta     r1H
	sta     mem_last_addr+1
	sta     assy_selected_instruction+1
	
	jsr     meta_clear_meta_data
	jsr     screen_clear_scrollback
	
	;; Let's write the program...
	ldx           #1
	jsr           edit_insert
	
	lda           #RTS_INSTRUCTION
	sta           (r1)
	MoveW         r1,r2

	LoadW         r1,str_main_label
	jsr           meta_add_label

@file_new_exit	
	jsr     clear_content
	sec                             ; Indicate done, return to main menu
	rts

;;
;; Save existing program
;;
file_save
	pushBankVar bank_assy
	callR1R2    read_string_with_prompt,filename_prompt,orig_file_name
	bcc         :+
	popBank    
	jmp         @file_save_exit

:  
	callR1R2    util_strcpy,input_string,orig_file_name
	popBank
	
	jsr        gotoPrompt
	ldx        screen_width
	dex
	jsr        prtspaceto

	ldx        #HDR_COL
	ldy        5
	callR1     prtstr_at_xy,str_saving_pgm

	callR1     prtstr,input_string

	;;
	;; Save program code
	;;
	lda   #0              ; logical file number
	ldx   #8              ; device number
	ldy   #1              ; 0 == load to address in file
	kerjsr SETLFS

	ldx   #<input_string
	ldy   #>input_string
	lda   input_string_length
	kerjsr SETNAME
	
	jsr   meta_get_region
	IncW   r1

	ldx   r1L
	ldy   r1H
	lda   #r0
	kerjsr SAVE

	;;
	;; Save META_L
	;;
	pushBankVar  bank_meta_l
	callR1       file_save_bank_a000,str_ext_dbg
	popBank

	;;
	;; Save META_I
	;;
	pushBankVar  bank_meta_i
	callR1       file_save_bank_a000,str_ext_dbi
	popBank

	lda     #0
	jsr     set_dirty
	
@file_save_exit
	sec
	rts

;
; Save bank A000-BFFF, to same filename as entered for the main program, but extension is passed in via r1
; Output C == 0: Save successful, C == 1: Save failed, error code in A
;
file_save_bank_a000
	;; Assume the SETLFS was called in saving the core program.                

	MoveW  r1,r2    ; r2 = extension string
	LoadW  r1,input_string
	LoadW  r3,file_open_seq_write_str
	jsr   file_replace_ext
	
	;; Rely on r1 being preserved
	lda    input_string_length
	sta    r2L
	lda    #4
	sta    r2H
	jsr    file_open
	bcs    @file_save_bank_a000_error
	
	ldx    #4
	kerjsr  CHKOUT

	LoadW  r0,$A000
	ldy    #0
	
	;;  Fake the load address, as if SAVE was called
	lda    r0L
	kerjsr CHROUT
	lda    r0H
	kerjsr CHROUT

@file_save_bank_a000_loop
	lda    (r0),y
	kerjsr CHROUT
	iny
	cpy    #0
	bne    @file_save_bank_a000_loop
	inc    r0H
	lda    r0H
	cmp    #$C0
	bne    @file_save_bank_a000_loop

@file_save_bank_a000_exit
	lda    #4
	kerjsr CLOSE

	ldx    #3
	kerjsr CHKOUT

	clc
	rts

@file_save_bank_a000_error
	jsr    file_set_error
	sec
	rts

;;
;; Load program 
;; Functional module to load a program, and attempt to load the debug information
;;
file_load_program
	jsr         dirty_query
	bne         @exe_load_program_exit
	
	pushBankVar bank_assy
	callR1R2    read_string_with_prompt,filename_prompt,orig_file_name
	bcc         @file_load_continue
	popBank
@exe_load_program_exit
	rts

@file_load_continue	
	callR1R2    util_strcpy,input_string,orig_file_name
	popBank
	
	jsr        gotoPrompt
	ldx        screen_width
	dex
	jsr        prtspaceto

	ldx        #0
	ldy        #5
	callR1     prtstr_at_xy,str_loading_pgm

	callR1     prtstr,input_string

	jsr        clear_program_settings

	jsr        screen_clear_scrollback
	
	ldy        SCR_COL
	ldx        SCR_ROW
	clc
	kerjsr     PLOT

	jsr        exe_load_the_program

	bcc        exe_load_next_step

	rts

exe_load_next_step
	ldx        #0
	ldy        #9
	callR1     prtstr_at_xy,str_loading_dbg

	pushBankVar bank_meta_l
	sec
	callR1     file_load_bank_a000,str_ext_dbg
	bcs        exe_load_error
	jsr        exe_load_setup_dbg
	popBank

	callR1      prtstr,str_loading_dbi
	pushBankVar bank_meta_i
	sec
	callR1      file_load_bank_a000,str_ext_dbi
	bcs         exe_load_error
	popBank

	jsr        gotoPrompt
	callR1     prtstr,str_loading_done

	sec
	rts

exe_load_error
	popBank
	jsr      clear_content
	jsr      gotoPrompt
	
;                callR1   prtstr,ERR_MSG
	lda      ERR_MSG
	sta      r1L
	lda      ERR_MSG+1
	sta      r1H
	jsr      prtstr

	jsr      meta_clear_meta_data
	clc
	rts

;;
;; Load the program
;;
exe_load_the_program
	lda   #0              ; logical file number
	ldx   #8              ; device number
	ldy   #1              ; 0 == load to address in file
	kerjsr SETLFS

	ldx   #<input_string
	ldy   #>input_string
	lda   input_string_length
	kerjsr SETNAME

	lda   #0
	kerjsr LOAD

	bcc   exe_load_the_program_no_error
	jsr   file_set_error
	sec                   ;; indicate an error
	rts

exe_load_the_program_no_error
	lda   #0              ; logical file number
	kerjsr CLOSE

	LoadW  r1,0
	jsr    meta_clear_watches
	
	rts

;;
;; Transfer specific meta into operating state variables.
;; called post debug load
;;
exe_load_setup_dbg
	;; Because bank_meta_l was completley filled, the bank selector rolled over.
	;; Need to reset it here. The caller will be popping the bank so it doesn't
	;; need to save bank context here.
	lda   bank_meta_l
	sta   BANK_CTRL_RAM
	
	lda   meta_exec_addr
	sta   assy_selected_instruction
	sta   mem_last_addr
	lda   meta_exec_addr+1
	sta   assy_selected_instruction+1
	sta   mem_last_addr+1
	rts
	
	
;;	Load the text decompiler into an $A000 bank, execute it.
;;	
file_save_text
	LoadW         r1,str_decompiler
	jsr           load_and_run_plugin
	clc
	rts
	
str_decompiler    .byte "CX-DC", 0

;; -------------------------------------------------------------------------------------------------
;;	
;;	Load the meta_i viewer into an $A000 bank, execute it.
;;	
meta_i_insp
	LoadW         r1,str_meta_i_insp
	jsr           load_and_run_plugin
	clc
	rts
	
str_meta_i_insp  .byte "CX-MII", 0


;;	
;;	Load the plugin (string in r1) and run it (in bank_plugin)
;;	Input r1 - String pointer to plugin executable name
;; 
load_and_run_plugin
	pushBankVar   bank_plugin
	
;	               callR1R2      util_strcpy,str_decompiler,input_string
	LoadW         r2,input_string
	jsr           util_strcpy

	callR1        file_load_bank_a000,0
	switchBankVar bank_assy
	callR1R2      util_strcpy,orig_file_name,decoded_str
	switchBankVar bank_plugin
	jsr           $a000
	popBank
	rts


;; -------------------------------------------------------------------------------------------------

;;
;; Break processor
;;
handle_break
	lda       BANK_CTRL_RAM
	pha

	;; Save register state
	lda       bank_assy
	sta       BANK_CTRL_RAM

	pla
	sta       brk_bank

	pla       
	sta       brk_data_y

	pla
	sta       brk_data_x

	pla       
	sta       brk_data_a

	pla       
	sta       brk_data_psr

	pla
	sta       brk_data_pc

	pla       
	sta       brk_data_pc+1

	tsx
	stx       brk_data_sp

	lda       FILE_LA
	sta       brk_data_la

	lda       FILE_FA
	sta       brk_data_fa

	lda       FILE_SA
	sta       brk_data_sa

	jsr       registers_save
	
	;; Adjust PC to handle the goofy +2 increment of the brk instruction
	jsr      debug_get_brk_adjustment
	sta      M2L
	lda      brk_data_pc
	sec
	sbc      M2L
	sta      brk_data_pc
	sta      mem_last_addr          ; Set up so dis-assy will display correct spot
	bcs      :+
	dec      brk_data_pc+1
:  
	lda      brk_data_pc+1
	sta      mem_last_addr+1        ; Set up so dis-assy will display correct spot

	lda      #01
	sta      brk_data_valid

	jsr      step_suspend
	
	lda       #3
	kerjsr    CHKIN

	;; DO BREAK STUFF HERE
	lda       brk_bank
	sta       BANK_CTRL_RAM

	jsr       save_vera_state
	jsr       save_user_screen

	jsr       break_loop

	jsr       restore_user_screen
	jsr       restore_vera_state

	;; Restore stack for an eventual RTI
	lda       bank_assy
	sta       BANK_CTRL_RAM 

	lda       brk_data_fa
	kerjsr    CHKIN

	lda       brk_data_pc+1
	pha

	lda       brk_data_pc
	pha

	lda       brk_data_psr
	pha

	jsr       registers_restore
	
	;; Restore A, X, Y, push PSR, PC
	ldx       brk_data_x

	ldy       brk_data_y

	lda       brk_data_a
	pha
	
	stz       brk_data_valid

	lda       brk_bank
	sta       BANK_CTRL_RAM

	pla
	rti

;;
;; Watch sub menu
;;
break_loop
	jsr     clear

break_in                                                        ; Oh no, a "break in", call the cops!
	lda        orig_color
	sta        K_TEXT_COLOR

	callR1     print_header,break_header

	jsr        main_display_core

	setDispatchTable break_dispatch_table

	jsr        get_and_dispatch
	bcs        break_abort

	cmp        #F4
	beq        break_exit

	bra        break_in

break_exit
	pushBankVar bank_assy
	lda        #WATCH_NON_HIGHLIGHT
	sta        watch_highlight
	popBank
	clc
	rts

break_abort
	lda        bank_assy
	sta        BANK_CTRL_RAM
	stz        brk_data_valid
	ldx        original_sp
	txs
	stz        BANK_CTRL_RAM
	jmp        main_loop

;;
;; Add step-breaks for next instruction
;; This routine will exit debug loop, with an implied continue
;;
break_step_over
	pushBankVar   bank_assy
	lda           brk_data_pc
	sta           r1L
	lda           brk_data_pc+1
	sta           r1H
	ldx           brk_bank
	popBank
	jsr           step_apply
	lda           #F4         ; So this command acts as a "continue"
	rts

;;; -------------------------------------------------------------------------------------
break_dispatch_table                
	.word   0               ; F1
	.word   0               ; F3
	.word   break_step_over ; F5
	.word   watch_loop      ; F7
	.word   view_loop       ; F2
	.word   0               ; F4
	.word   0               ; F6

;;; -------------------------------------------------------------------------------------
	.code
	
;;
;; Initialize break vector to the env
;;
init_break_vector
	pushBankVar bank_assy
	lda     BRK_VECTOR
	sta     old_brk_vector
	lda     BRK_VECTOR+1
	sta     old_brk_vector+1

	lda     #<handle_break
	sta     BRK_VECTOR
	lda     #>handle_break
	sta     BRK_VECTOR+1
	popBank
	rts

restore_break_vector
	pushBankVar bank_assy
	lda     old_brk_vector
	sta     BRK_VECTOR
	lda     old_brk_vector+1
	sta     BRK_VECTOR+1

	lda     bank_rom_orig
	sta     BANK_CTRL_ROM
	
	popBank
	rts

;;
;; Clear program settings, set up for a new program
;;
clear_program_settings
	jsr     init_state_variables
	stz     r1L
	stz     r1H
	jsr     meta_clear_meta_data
	jsr     meta_clear_watches
	lda     #0
	jsr     set_dirty
	rts

;;
;; Initialize other state variables
;;
init_state_variables
	stz     mem_last_addr
	stz     mem_last_addr+1

	pushBankVar bank_assy
	stz     brk_data_pc
	stz     brk_data_pc+1
	stz     screen_save_plot_x
	stz     screen_save_plot_y
	lda     #MODE_80_60
	sta     screen_save_mode
	popBank
	
	rts

;;
;; Set dirty bit to value in A
;;
set_dirty
	tay
	pushBankVar bank_assy
	sty         assy_dirty
	popBank
	rts

;;	
;;	 Query the dirty bit, and ask user what to do
;;	 Return Z == 1, means user says EXIT, or was not dirty in first place
;;         Z == 0, means user says NO EXIT 
;;	
;;	
dirty_query	
	pushBankVar    bank_assy
	ldx            assy_dirty
	popBank
	txa
	
	beq     @dirty_query_exit
	
	lda     orig_color
	sta     K_TEXT_COLOR
	
	callR1  read_key_with_prompt,str_is_dirty
	cmp     #'Y'
@dirty_query_exit	
	rts

	.endproc

;;	
;;	Clear the area under the header
;;	
clear_content
	vgotoXY 0,HDR_ROW+3
	ldx     #80
	ldy     #57
	jsr     erase_box
	rts

	.end
