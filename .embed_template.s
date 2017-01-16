bits 64
section .rodata

%macro MAKE_TABLE 1-*
	%rep %0
	extern _%1_symtable
	%rotate 1
	%endrep

	%rep %0
	%rotate -1
	%endrep

	global _g_embedded_mod_table

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

_g_embedded_mod_table:
	
	%rep %0
	dq _str_%1
	dq _%1_symtable
	%rotate 1
	%endrep
	
	dq 0
	dq 0
%endmacro

MAKE_TABLE OBJECTS
