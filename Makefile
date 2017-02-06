SHELL := bash

boot-bg.%.png: boot-bg.svg
	inkscape --without-gui --export-png=$@ --export-background='#35479a' -w 1024 <(sed s/@YEAR@/$*/ $<)

