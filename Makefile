# Makefile — deck PDF generator helpers
PY        := python3
OUT_DIR   := out
TOOLS_DIR := tools
HTML_DIR  := pages
DOCS_DIR  := DOC

TITTLE    := New York Mafia

# Enable colored output (1 = on, 0 = off)
ENABLE_COLOR ?= 1

ifeq ($(ENABLE_COLOR),1)
RED    := $(shell printf '\033[0;31m')
GREEN  := $(shell printf '\033[0;32m')
YELLOW := $(shell printf '\033[0;33m')
BLUE   := $(shell printf '\033[0;34m')
BOLD   := $(shell printf '\033[1m')
RESET  := $(shell printf '\033[0m')
else
RED :=
GREEN :=
YELLOW :=
BLUE :=
BOLD :=
RESET :=
endif

# XSLT mode: front | back | both
MODE      ?= both
COLOR     ?= color
# Default input: single XML file. Override like:
#   make render-file INPUT=cards/cards.xml
INPUT     ?= cards/cards.xml

# Default base cards directory (render this when no DLC selected)
BASE_CARDS := cards/base_game
# If you want to include DLC(s) in addition to base, set `DLC_NAMES` to a
# space-separated list of subdirectories under `cards`, e.g. `make DLC_NAMES="DLC" render`
DLC_NAMES ?=
DLC_ALL   := base_game DLC
# By default render uses the base-game cards directory
CARDS_DIR ?= $(BASE_CARDS)

# Build list of source directories for the merger.
# If DLC_NAMES is set we render only the listed DL(s) (no base game).
ifeq ($(strip $(DLC_NAMES)),)
MERGE_SRCS := $(CARDS_DIR)
else
MERGE_SRCS := $(foreach d,$(DLC_NAMES),cards/$(d))
endif

# Default XML and XSLT files for html-table and python-merge targets
XML_IN 	  	?= cards/*.xml
XSL_CARDS 	:= $(TOOLS_DIR)/cards_to_html.xslt
XSL_TABLE 	:= $(TOOLS_DIR)/cards_to_table.xslt
XSD       	:= cards/cards.xsd

# For html-table and python-merge targets
MERGED 		:= $(HTML_DIR)/cards_merged.xml

# List of card source directories (cards/base_game plus any DLC subdirs)
CARD_SRCDIRS := $(shell for d in cards/*; do [ -d "$$d" ] && [ "$$(basename $$d)" != "config" ] && echo "$$d"; done)

HTML_FRONT  := $(HTML_DIR)/cards_front.html
HTML_BACK   := $(HTML_DIR)/cards_back.html
HTML_BOTH   := $(HTML_DIR)/cards_both.html
HTML_TABLE  := $(HTML_DIR)/cards_table.html

PDF_FRONT := $(OUT_DIR)/cards_front.pdf
PDF_BACK  := $(OUT_DIR)/cards_back.pdf
PDF_BOTH  := $(OUT_DIR)/cards_both.pdf

.PHONY: all render-file validate deps clean help html-table python-merge
.PHONY: python-merge html-table final-deck html pdf pdf-front pdf-back pdf-both merge

all: pdf 

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

$(HTML_DIR):
	mkdir -p $(HTML_DIR)

help:
	@echo "Usage: make [target]"
	@echo "Targets:"
	@echo "  help           - show this help"
	@echo "  validate       - validate INPUT against $(XSD) using validate_xml from render script"
	@echo "  python-merge   - merge XML files from base or optional DLC(s) into $(MERGED)"
	@echo "  html-table     - generate an HTML table of all cards (requires xsltproc)"
	@echo "  html-cards     - generate HTML files for printable cards (front/back/both)"
	@echo "  html           - generate front/back/both HTML using current XSL (uses python merger when cards/ is present)"
	@echo "  pdf            - generate PDFs from the HTML outputs (frontend conversion scripts required)"
	@echo "  MODE=[front|back|both] - set XSLT mode for html-cards/html (default both)"
	@echo "  clean          - remove generated PDFs and HTML in $(OUT_DIR) and $(HTML_DIR)"

validate:
	@if [ -n "$(strip $(DLC_NAMES))" ]; then \
		printf "$(YELLOW)Merging $(BLUE)%s$(YELLOW) into $(BLUE)%s$(RESET) and validating...\n" "$(DLC_NAMES)" "$(MERGED)"; \
		$(PY) $(TOOLS_DIR)/merge_cards.py $(MERGE_SRCS) $(MERGED); \
		bash $(TOOLS_DIR)/validate_cards.sh "$(MERGED)" "$(XSD)"; \
	elif [ -d "$(CARDS_DIR)" ]; then \
		printf "$(YELLOW)Validating from $(BLUE)%s$(RESET) against $(BLUE)%s$(RESET)\n" "$(CARDS_DIR)" "$(XSD)"; \
		bash $(TOOLS_DIR)/validate_cards.sh "$(CARDS_DIR)" "$(XSD)"; \
	else \
		printf "$(YELLOW)Validating input dir $(BLUE)%s$(RESET) against $(BLUE)%s$(RESET)\n" "$(dir $(INPUT))" "$(XSD)"; \
		bash $(TOOLS_DIR)/validate_cards.sh "$(dir $(INPUT))" "$(XSD)"; \
	fi

deps:
	@./install.sh

# Python-based merger of multiple XML files from cards/ into single merged XML
python-merge:
	$(PY) $(TOOLS_DIR)/merge_cards.py $(MERGE_SRCS) $(MERGED)

final-deck: python-merge $(OUT_DIR)
	@$(PY) "$(SCRIPT)" -i "$(MERGED)" --zero-gaps -o "$(OUT_DIR)"
	@printf "$(GREEN)Generated final deck PDF(s) in $(BLUE)%s$(GREEN) (from $(BLUE)%s$(GREEN))$(RESET)\n" "$(OUT_DIR)" "$(MERGED)"

merge: validate $(OUT_DIR)
	@# Use the python merger which accepts one or more source directories
	@printf "$(YELLOW)Merging XML files from $(BLUE)%s$(YELLOW) into $(BLUE)%s$(RESET) using Python merger...\n" "$(MERGE_SRCS)" "$(MERGED)"
	$(PY) $(TOOLS_DIR)/merge_cards.py $(MERGE_SRCS) $(MERGED)

# Generate an HTML table of all cards from merged XML
rules-pandoc: $(OUT_DIR)
	@printf "$(YELLOW)Converting custom admonition syntax to bold headings for Pandoc.$(RESET)\n"
	sed \
	  -e 's/^> \[!tip\]/> **TIP**/I' \
	  -e 's/^> \[!note\]/> **NOTE**/I' \
	  -e 's/^> \[!warning\]/> **WARNING**/I' \
	  -e 's/^> \[!important\]/> **IMPORTANT**/I' \
	  -e 's/^> \[!question\]/> **QUESTION**/I' \
	  $(DOCS_DIR)/rules.md > $(OUT_DIR)/rules_pandoc.md

html-rules: rules-pandoc
	@printf "$(YELLOW)Moving CSS files to HTML directory.$(RESET)\n"
	cp $(DOCS_DIR)/style.css $(HTML_DIR)/
	cp $(DOCS_DIR)/print.css $(HTML_DIR)/
	@printf "$(YELLOW)Generating HTML rules from Markdown using Pandoc.$(RESET)\n"
	pandoc $(OUT_DIR)/rules_pandoc.md --standalone --metadata title="$(TITTLE)" --css style.css -o $(HTML_DIR)/index.html
	pandoc $(OUT_DIR)/rules_pandoc.md --standalone --metadata title="$(TITTLE)" --css print.css -o $(HTML_DIR)/rules_print.html

html-stats: merge
	@xsltproc -o $(HTML_DIR)/stats.html $(TOOLS_DIR)/cards_to_stats.xslt $(MERGED)
	@printf "$(GREEN)Generated $(BLUE)%s$(RESET)\n" "$(HTML_DIR)/stats.html"

# Generate stats pages for each card source directory (base_game + DLCs)
html-stats-all:
	@mkdir -p $(HTML_DIR)
	@for d in $(CARD_SRCDIRS); do \
		name=$$(basename $$d); \
		merged=$(HTML_DIR)/cards_merged_$$name.xml; \
		out=$(HTML_DIR)/stats-$$name.html; \
		printf "$(YELLOW)Merging $(BLUE)%s$(YELLOW) into $(BLUE)%s$(RESET)\n" "$$d" "$$merged"; \
		$(PY) $(TOOLS_DIR)/merge_cards.py $$d $$merged; \
		xsltproc -o $$out $(TOOLS_DIR)/cards_to_stats.xslt $$merged; \
		printf "$(GREEN)Generated $(BLUE)%s$(RESET)\n" "$$out"; \
	done

html-table: merge $(HTML_DIR)
	@xsltproc -o $(HTML_TABLE) $(XSL_TABLE) $(MERGED)
	@printf "$(GREEN)Generated $(BLUE)%s$(RESET)\n" "$(HTML_TABLE)"

# Generate HTML table pages for each card source directory (base_game + DLCs)
html-table-all: $(HTML_DIR)
	@for d in $(CARD_SRCDIRS); do \
		name=$$(basename $$d); \
		merged=$(HTML_DIR)/cards_merged_$$name.xml; \
		out=$(HTML_DIR)/cards_table_$$name.html; \
		printf "$(YELLOW)Merging $(BLUE)%s$(YELLOW) into $(BLUE)%s$(RESET)\n" "$$d" "$$merged"; \
		$(PY) $(TOOLS_DIR)/merge_cards.py $$d $$merged; \
		xsltproc -o $$out $(TOOLS_DIR)/cards_to_table.xslt $$merged; \
		printf "$(GREEN)Generated $(BLUE)%s$(RESET)\n" "$$out"; \
	done

html-cards: merge
	@xsltproc --stringparam mode $(MODE) --stringparam colorMode $(COLOR) -o $(HTML_BOTH) $(XSL_CARDS) $(MERGED)
	@printf "$(GREEN)Generated html out of cards for PDF(s) in $(BLUE)%s$(GREEN) (from $(BLUE)%s$(GREEN)) (mode=$(BLUE)%s$(GREEN), color=$(BLUE)%s$(GREEN))$(RESET)\n" "$(OUT_DIR)" "$(MERGED)" "$(MODE)" "$(COLOR)"

html-front: merge
	@xsltproc --stringparam mode front --stringparam colorMode $(COLOR) -o $(HTML_FRONT) $(XSL_CARDS) $(MERGED)

html-back: merge
	@xsltproc --stringparam mode back --stringparam colorMode $(COLOR) -o $(HTML_BACK) $(XSL_CARDS) $(MERGED)

html-both: merge
	@xsltproc --stringparam mode both --stringparam colorMode $(COLOR) -o $(HTML_BOTH) $(XSL_CARDS) $(MERGED)

# HTML build now produces per-directory pages for tables and stats
html: html-table-all html-stats-all html-rules html-cards html-both $(HTML_DIR)
	cp -r assets $(HTML_DIR)/
	@printf "$(YELLOW)Selected mode=$(BLUE)%s$(YELLOW) color=$(BLUE)%s$(RESET)\n" "${MODE}" "${COLOR}"
	@printf "$(GREEN)HTML files generation complete.$(RESET)\n"

# Generate PDFs from HTML files
pdf-rules: html-rules
	./tools/html_to_pdf.sh $(HTML_DIR)/rules_print.html $(OUT_DIR)/rules.pdf
	@printf "  Rules: $(BLUE)$(OUT_DIR)/rules.pdf$(RESET)\n"

pdf-front: html
	./tools/html_to_pdf.sh $(HTML_FRONT) $(PDF_FRONT)
	@printf "  Front: $(BLUE)$(PDF_FRONT)$(RESET)\n"

pdf-back: html
	./tools/html_to_pdf.sh $(HTML_BACK) $(PDF_BACK)
	@printf "  Back:  $(BLUE)$(PDF_BACK)$(RESET)\n"

pdf-both: html
	./tools/html_to_pdf.sh $(HTML_BOTH) $(PDF_BOTH)
	@printf "  Both:  $(BLUE)$(PDF_BOTH)$(RESET)\n"

pdf: pdf-both pdf-rules
	@printf "$(GREEN)Generated PDFs in $(BLUE)%s$(GREEN) folder.$(RESET)\n" "$(OUT_DIR)"

# Remove generated PDFs and HTML files
clean:
	rm -f "$(OUT_DIR)"/*.pdf
	rm -f "$(HTML_DIR)"/*.html
	rm -f "$(HTML_DIR)"/*.xml