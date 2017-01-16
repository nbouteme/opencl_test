%define START_LABEL _start_ %+ NAME
%define END_LABEL _end_ %+ NAME
%define SIZE_LABEL _size_ %+ NAME
%defstr FILE PATH

bits 64
section .rodata
global START_LABEL
global END_LABEL
global SIZE_LABEL
START_LABEL: incbin FILE
END_LABEL:
SIZE_LABEL: dd $-START_LABEL
