# Makefile — deck PDF generator helpers
PY		:= python3
OUT_DIR   := out
TOOLS_DIR := tools
HTML_DIR  := pages
DOCS_DIR  := DOC
ASSETS_DIR := assets
HTML_SRC_DIR := html

TITTLE	:= New York Mafia

# Enable colored output (1 = on, 0 = off)
ENABLE_COLOR ?= 1

ifeq ($(ENABLE_COLOR),1)
RED	   := $(shell printf '\033[0;31m')
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
MODE	 ?= both
COLOR	 ?= color

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
XSD	   	    := cards/cards.xsd

# For html-table and python-merge targets
MERGED 		:= $(HTML_DIR)/cards_merged.xml

# List of card source directories (cards/base_game plus any DLC subdirs)
CARD_SRCDIRS := $(shell for d in cards/*; do [ -d "$$d" ] && [ "$$(basename $$d)" != "config" ] && echo "$$d"; done)

HTML_FRONT  := $(HTML_DIR)/cards_front.html
HTML_BACK   := $(HTML_DIR)/cards_back.html
HTML_CARDS  := $(HTML_DIR)/cards_both.html
HTML_TABLE  := $(HTML_DIR)/cards_table.html

PDF_FRONT := $(OUT_DIR)/cards_front.pdf
PDF_BACK  := $(OUT_DIR)/cards_back.pdf
PDF_BOTH  := $(OUT_DIR)/cards_both.pdf


ASSETS_STAMP := $(HTML_DIR)/assets/.optimized
DEPS_LISTS := $(wildcard pip-dependencies.txt apt-dependencies.txt)

.PHONY: all validate merge html-rules html-table html-cards html pdf clean deps help

all: pdf 

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

$(HTML_DIR):
	mkdir -p $(HTML_DIR)

help:
	@echo "Usage: make [target]"
	@echo "Targets:"
	@echo "  help			- show this help"
	@echo "  deps			- install dependencies (Python packages, etc.) using install.sh"
	@echo "  validate		- validate INPUT against $(XSD) using validate_xml from render script"
	@echo "  merge  		- merge XML files from base or optional DLC(s) into $(MERGED)"
	@echo "  html-table		- generate an HTML table of all cards (requires xsltproc)"
	@echo "  html-cards		- generate HTML files for printable cards (front/back/both)"
	@echo "  html			- generate front/back/both HTML using current XSL (uses python merger when cards/ is present)"
	@echo "  pdf			- generate PDFs from the HTML outputs (frontend conversion scripts required)"
	@echo "  MODE=[front|back|both] - set XSLT mode for html-cards/html (default both)"
	@echo "  clean		 	- remove generated PDFs and HTML in $(OUT_DIR) and $(HTML_DIR)"

deps: $(OUT_DIR)/.packages_installed | $(OUT_DIR)
$(OUT_DIR)/.packages_installed: $(DEPS_LISTS)
	@printf "$(YELLOW)Installing dependencies from $(BLUE)$^$(RESET)...\n"
	@./install.sh
	@touch $@

validate: $(OUT_DIR)/.validated
$(OUT_DIR)/.validated: $(shell find $(CARDS_DIR) -type f -name '*.xml') $(XSD) | $(OUT_DIR)
	@printf "$(YELLOW)Validating from $(BLUE)%s$(RESET) against $(BLUE)%s$(RESET)\n" "$(CARDS_DIR)" "$(XSD)"
	@./$(TOOLS_DIR)/validate_cards.sh "$(CARDS_DIR)" "$(XSD)"
	@touch $@

merge: $(MERGED)
$(MERGED): $(OUT_DIR)/.validated | $(OUT_DIR)
	@printf "$(YELLOW)Merging XML files from $(BLUE)%s$(YELLOW) into $(BLUE)%s$(RESET) using Python merger...\n" "$(MERGE_SRCS)" "$(MERGED)"
	$(PY) $(TOOLS_DIR)/merge_cards.py $(MERGE_SRCS) $@

pandoc-rules: $(OUT_DIR)/rules_pandoc.md
$(OUT_DIR)/rules_pandoc.md: $(DOCS_DIR)/rules.md | $(OUT_DIR)
	@printf "$(YELLOW)Converting custom admonition syntax to bold headings for Pandoc.$(RESET)\n"
	sed \
	  -e 's/^> \[!tip\]/> **TIP**/I' \
	  -e 's/^> \[!note\]/> **NOTE**/I' \
	  -e 's/^> \[!warning\]/> **WARNING**/I' \
	  -e 's/^> \[!important\]/> **IMPORTANT**/I' \
	  -e 's/^> \[!question\]/> **QUESTION**/I' \
	  $(DOCS_DIR)/rules.md > $@

CSS_TARGETS := $(patsubst $(DOCS_DIR)/%.css,$(HTML_DIR)/%.css,$(wildcard $(DOCS_DIR)/*.css))

$(HTML_DIR)/%.css: $(DOCS_DIR)/%.css | $(HTML_DIR)
	@printf "$(YELLOW)Copying CSS: $(BLUE)$<$(RESET) -> $(BLUE)$@$(RESET)\n"
	cp $< $@

$(HTML_DIR)/index.html: $(OUT_DIR)/rules_pandoc.md $(HTML_DIR)/style.css | $(HTML_DIR)
	@printf "$(YELLOW)Generating index.html from Markdown using Pandoc.$(RESET)\n"
	pandoc $< --standalone --metadata title="$(TITTLE)" --css style.css -o $@

$(HTML_DIR)/rules_print.html: $(OUT_DIR)/rules_pandoc.md $(HTML_DIR)/print.css | $(HTML_DIR)
	@printf "$(YELLOW)Generating HTML rules from Markdown using Pandoc.$(RESET)\n"
	pandoc $< --standalone --metadata title="$(TITTLE)" --css print.css -o $@

html-rules: $(HTML_DIR)/index.html $(HTML_DIR)/rules_print.html $(CSS_TARGETS)

html-table: $(HTML_TABLE) $(ASSETS_STAMP)
$(HTML_TABLE): $(XSL_TABLE) $(MERGED) | $(HTML_DIR)
	@xsltproc -o $(HTML_TABLE) $(XSL_TABLE) $(MERGED)
	@printf "$(GREEN)Generated $(BLUE)%s$(RESET)\n" "$(HTML_TABLE)"

html-cards: $(HTML_CARDS) $(ASSETS_STAMP)
$(HTML_CARDS): $(XSL_CARDS) $(MERGED) | $(HTML_DIR)
	@xsltproc --stringparam mode $(MODE) --stringparam colorMode $(COLOR) -o $(HTML_CARDS) $(XSL_CARDS) $(MERGED)
	@printf "$(GREEN)Generated html out of cards for PDF(s) in $(BLUE)%s$(GREEN) (from $(BLUE)%s$(GREEN)) (mode=$(BLUE)%s$(GREEN), color=$(BLUE)%s$(GREEN))$(RESET)\n" "$(OUT_DIR)" "$(MERGED)" "$(MODE)" "$(COLOR)"

$(ASSETS_STAMP): $(shell find $(ASSETS_DIR) -type f) | $(HTML_DIR)
	@printf "$(YELLOW)Optimizing images from $(ASSETS_DIR)/ to $(HTML_DIR)/assets/$(RESET)\n"
	$(PY) $(TOOLS_DIR)/optimize_images.py $(ASSETS_DIR) $(HTML_DIR)/assets
	@touch $@

$(HTML_DIR)/kostky.html: $(HTML_SRC_DIR)/kostky.html | $(HTML_DIR)
	@printf "$(YELLOW)Copying kostky.html to $(HTML_DIR)/$(RESET)\n"
	cp $(HTML_SRC_DIR)/kostky.html $@

$(HTML_DIR)/zetony.html: $(HTML_SRC_DIR)/zetony.html | $(HTML_DIR)
	@printf "$(YELLOW)Copying zetony.html to $(HTML_DIR)/$(RESET)\n"
	cp $(HTML_SRC_DIR)/zetony.html $@

# HTML build now produces per-directory pages for tables and stats
html: $(ASSETS_STAMP) html-rules $(HTML_CARDS) $(HTML_TABLE) $(HTML_DIR)/kostky.html $(HTML_DIR)/zetony.html | $(HTML_DIR)
	@printf "$(YELLOW)Selected mode=$(BLUE)%s$(YELLOW) color=$(BLUE)%s$(RESET)\n" "${MODE}" "${COLOR}"
	@printf "$(GREEN)HTML files generation complete.$(RESET)\n"

# Generate PDFs from HTML files
$(OUT_DIR)/rules.pdf: $(HTML_DIR)/rules_print.html | $(OUT_DIR)
	./tools/html_to_pdf.sh $(HTML_DIR)/rules_print.html $(OUT_DIR)/rules.pdf
	@printf "  Rules: $(BLUE)$(OUT_DIR)/rules.pdf$(RESET)\n"

$(PDF_BOTH): $(HTML_CARDS) | $(OUT_DIR)
	./tools/html_to_pdf.sh $(HTML_CARDS) $(PDF_BOTH)
	@printf "  Cards:  $(BLUE)$(PDF_BOTH)$(RESET)\n"

pdf: $(PDF_BOTH) $(OUT_DIR)/rules.pdf
	@printf "$(GREEN)Generated PDFs in $(BLUE)%s$(GREEN) folder.$(RESET)\n" "$(OUT_DIR)"

# Remove generated PDFs and HTML files
clean:
	rm -rf "$(OUT_DIR)"
	rm -rf "$(HTML_DIR)"