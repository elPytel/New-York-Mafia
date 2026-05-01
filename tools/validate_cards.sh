#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   validate_cards.sh [path] [schema]
# If `path` is a directory, validate all .xml files in it (non-recursive).
# If `path` is a file, validate that file. If omitted, use current directory.
# `schema` defaults to `cards/cards.xsd`.

path="${1:-cards}"
schema="${2:-cards/cards.xsd}"

# Colored output (echo -e is fine — script uses bash)
ENABLE_COLOR="${ENABLE_COLOR:-1}"
if [ "${ENABLE_COLOR}" != "0" ]; then
	RED="\033[0;31m"
	GREEN="\033[0;32m"
	YELLOW="\033[0;33m"
	BLUE="\033[0;34m"
	RESET="\033[0m"
else
	RED=""
	GREEN=""
	YELLOW=""
	BLUE=""
	RESET=""
fi

if [ ! -f "$schema" ]; then
	echo -e "${RED}Schema not found:${RESET} ${BLUE}$schema${RESET}" >&2
	exit 2
fi

validate_file() {
	local file="$1"
	if [ ! -f "$file" ]; then
		echo -e "${YELLOW}Skipping missing file:${RESET} ${BLUE}$file${RESET}" >&2
		return
	fi
	echo -e "Validating ${BLUE}$file${RESET} against ${BLUE}$schema${RESET} (processing XIncludes)"
	tmpfile=$(mktemp /tmp/validate_cards.XXXXXX.xml)
	# Remove XInclude lines before validation (the schema expects only <card> elements)
	sed '/xi:include/d' "$file" > "$tmpfile"
	if ! xmllint --noout --schema "$schema" "$tmpfile"; then
		echo -e "${RED}Validation failed for${RESET} ${BLUE}$file${RESET}" >&2
		rm -f "$tmpfile"
		return 3
	fi
	rm -f "$tmpfile"
}

all_passed=true
if [ -d "$path" ]; then
	# Find XML files (non-recursive) and validate each
	found=false
	while IFS= read -r -d '' file; do
		found=true
		validate_file "$file" || all_passed=false
	done < <(find "$path" -maxdepth 1 -type f -name '*.xml' -print0 | sort -z)
	if ! $found; then
		echo -e "${RED}No XML files found in directory:${RESET} ${BLUE}$path${RESET}" >&2
		exit 1
	fi
else
	# treat path as a file
	validate_file "$path"
fi

if ! $all_passed; then
    echo -e "${RED}Some files failed validation${RESET}" >&2
    exit 1
fi

echo -e "${GREEN}Validation complete:${RESET} ${BLUE}all files passed${RESET}"
exit 0
# End of script