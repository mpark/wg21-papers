PAPER_RULE := D2688R7:match
-include ../local.mk
include ../wg21/paper.mk

TYPST ?= typst

.PHONY: slides
slides: slides/P2688R6-clang-llvm.pdf

slides/P2688R6-clang-llvm.pdf: slides/P2688R6-clang-llvm.typ
	$(TYPST) compile $< $@

slides/P2688R6-clang-llvm-notes.pdf: slides/P2688R6-clang-llvm.typ
	$(TYPST) compile --input speaker-notes=true $< $@
