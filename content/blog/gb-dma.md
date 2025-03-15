---
title: "The DMA inside the Gameboy"
date: 2025-01-07T17:27:59+07:00
---

This article will explain how to use the DMA of the Gameboy DMG in assembly
language. Of course it will assume familiarity with the language itself.

## Why use the DMA?
The job of the DMA is to move data from one section of the memory to another.
The DMA of the Gameboy is design to move 160 bytes in 160 machine cycles. 

*But the CPU has instruction to do the same thing, why use the DMA?*

An example of code to move data from `$FF81` to `$C001` would be as follow

```armasm
ld	hl, $FF81	; hl points to source address		(3 cycles)
ld	a, [hl]		; a store the in it					(2 cycles)
ld	hl, $C001	; hl now points to destination add.	(3 cycles)
ld	[hl], a		; copy content of $FF81 to $C001	(2 cycles)
```

In total this code will take 10 cycles to copy one byte of data. Now imagine
writing this for 160 bytes, it would take 160*10=1600 machine cycles! The DMA
seems like a much more convenient solution, since it takes a tenth of cycles.


## Cool, but what to transfer then?
A constraint of the Gameboy is the inability to update the OAM (the sprite
memory) while the screen is been refreshed. The [Pan Docs][1] shows that the OAM
is exacly 160 bytes long. The problem above could be overcome by using 160
bytes of WRAM as OAM and the code could change that memory section without any
constraint. When VBlank interrupt occurs the code lunch the DMA that copies
the WRAM data to the actual OAM.


## How to use the DMA

To start the DMA the address `$FF46` has to be written with the source address
divided by `$100` and the DMA will transfer 160 bytes from source to OAM (the
destination address is set by default to be OAM). Suppose to use the first 160
bytes of WRAM as source (from `C000` to `C09F`), the code to use the DMA would
be

```armasm
	; start the DMA
	ld	a, $C000 / $100		; load the source address divided by $100
	ld	$FF46, a			; start the DMA

	; wait the DMA to finish
	ld	a, 40	; this number will be explained shortly
.dma_wait:
	dec	a				; 1 cycle
	jr	nz, .dma_wait	; 3 cycles
```

in 160 machine cycles the content from $C000-$C09F will be copied to
$FE00-$FE9F.

The reason of the load 40 into register a is simple. The CPU has to wait 160
cycles for the DMA to finish. Inside the loop there are two instruction: dec
and jr that take 1 and 3 cycles respectivly. So one loop iteration takes 1+3=4
cycles. To get the number of loops that the CPU has to do to wait the exac time
is simply 160/4=40.

Since the interrupt can occur any time and the code use register a to start and
wait the DMA, if a is storing an important value it would be lost. Using the
HRAM as stack can solve this problem. The code would be

```armasm
	push	af
	; start the DMA
	ld	a, $C000 / $100		; load the source address divided by $100
	ld	$FF46, a			; start the DMA

	; wait the DMA to finish
	ld	a, 40	; this number will be explained shortly
.dma_wait:
	dec	a				; 1 cycle
	jr	nz, .dma_wait	; 3 cycles
	pop	af
```

There is another problem thought, while the DMA is running the CPU can access
only HRAM (that's the reason that the stack is in there). This means that the
CPU can execute code only from that region of memory. So the code above must be
copied to HRAM. To understand how to do it a deeper understanding on how the CPU
execute code is needed. When compiling the armasm code with rgbds toolchain it
results in a .gb file. Doing an hexdump of the rom it result in something like
this

```
$ hexdump hello-world.gb
000000 0000 0000 0000 0000 0000 0000 0000 0000
*
0000100 50c3 0001 edce 6666 0dcc 0b00 7303 8300
0000110 0c00 0d00 0800 1f11 8988 0e00 ccdc e66e
0000120 dddd 99d9 bbbb 6367 0e6e ccec dcdd 9f99
0000130 b9bb 3e33 0000 0000 0000 0000 0000 0000
0000140 0000 0000 0000 0000 0000 0000 e700 d83c
0000150 003e 26e0 44f0 90fe 54da 3e01 e000 1140
0000160 018e 0021 0190 0460 221a 0b13 b178 68c2
0000170 1101 05ee 0021 0198 0240 221a 0b13 b178
...
```

where the first number, for example "0000100", is the memory address of the
first byte and then follows the actual 16 bytes with data. This is hexadecimal
so it's just a compact way to write one and zero. This is what the CPU use to
understand what instruction to use. Every instruction has an *opcode* in other
words a byte that rapresent that [instruction][2]. For example the instruction
that disable interrupts has the opcode of "F3" ("11110011" in binary).

Going back to the problem of coping the code into HRAM a solution could be
writing at the initialization of the Gameboy a set of instructions that copy the
opcode of the code that the CPU has to execute to start&wait the DMA into HRAM.
It could be something like this (taken from the [DMGReport][3])

```armasm
DMA_ROUTINE	= $FF80	; first address of HRAM
rDMA = $FF46
OAMDATALOC	= _RAM	; set first 160 bytes of RAM to hold OAM variables
OAMDATALOCBANK	= OAMDATALOC / $100 ; used by DMA_ROUTINE to point to _RAM

SECTION "Vblank", ROM0[$0040]
	JP	DMA_ROUTINE

dma_Copy2HRAM:
	jr	.copy_dma_into_memory
.dmacode
	push	af
	ld	a, OAMDATALOCBANK
	ldh	[rDMA], a
	ld	a, $28 ; countdown until DMA is finishes, then exit
.dma_wait				;<-|
	dec	a				;  |	keep looping until DMA finishes
	jr	nz, .dma_wait   ; _|
	pop	af
	reti	; if this were jumped to by the v-blank interrupt, we'd
			; want to reti (re-enable interrupts).
.dmaend
.copy_dma_into_memory
	ld	de, DMA_ROUTINE
	ld	hl, .dmacode
	ld	bc, .dmaend - .dmacode
; mem_Copy copies BC # of bytes from source (HL) to destination (DE)
; so it copies the opcode of every instruction from .dmacode to .dmaend
; (that are in ROM) to HRAM
.mem_Copy
	inc	b
	inc	c
	jr	.skip
.loop
	ld	a, [hl+]
	ld	[de], a
	inc	de
.skip
	dec	c
	jr	nz,.loop\@
	dec	b
	jr	nz,.loop\@
```

It's a lot of stuff, but it isn't hard, let's walk throught that. At the
beggining some constants are defined, and then comes 

```armasm
SECTION "Vblank", ROM0[$0040]
	JP	DMA_ROUTINE
```

when the "Vblank" interrupt occurs it execute this portion of code, which, in
this case, is jumping at DMA_ROUTINE address that is set to be HRAM. Next comes
the actual code. The portion included from ".dmacode" to ".dmaend" is identical
at the one previusly discussed, so no problem here. Then there is the actual
copy

```armasm
.copy_dma_into_memory
	ld	de, DMA_ROUTINE
	ld	hl, .dmacode
	ld	bc, .dmaend - .dmacode
; mem_Copy copies BC # of bytes from source (HL) to destination (DE)
; so it copies the opcode of every instruction from .dmacode to .dmaend
; (that are in ROM) to HRAM
.mem_Copy
	inc	b
	inc	c
	jr	.skip
.loop
	ld	a, [hl+]
	ld	[de], a
	inc	de
.skip
	dec	c
	jr	nz,.loop\@
	dec	b
	jr	nz,.loop\@
```

[1]: https://gbdev.io/pandocs/Memory_Map.html
[2]: https://www.pastraiser.com/cpu/gameboy/gameboy_opcodes.html
[3]: https://github.com/lancekindle/DMGreport/blob/master/03_good_sprite_moves.armasm
