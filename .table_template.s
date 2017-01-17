bits 64
section .rodata

%define TABLE_NAME _ %+ EPATH %+ _symtable
	
%macro MAKE_TABLE 1-*
	%rep %0
	extern _start_%1
	extern _end_%1
	extern _size_%1
	%rotate 1
	%endrep

	%rep %0
	%rotate -1
	%endrep

	global TABLE_NAME

	%rep %0
	%defstr STRING_EQ %1
_str_%1:
	db STRING_EQ, 0
	%undef STRING_EQ
	%rotate 1
	%endrep

	%rep %0
	%rotate -1
	%endrep

TABLE_NAME:
	
	%rep %0
	dq _str_%1
	dq _start_%1
	dq _size_%1
	dq 0
	%rotate 1
	%endrep
	
	dq 0
	dq 0
	dq 0
	dq 0
%endmacro

MAKE_TABLE OBJECTS
