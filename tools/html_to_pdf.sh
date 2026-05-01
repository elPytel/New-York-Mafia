#!/usr/bin/env bash
set -euo pipefail

IN_HTML="${1:-}"
OUT_PDF="${2:-}"

if [[ -z "$IN_HTML" || -z "$OUT_PDF" ]]; then
  echo "Usage: $0 input.html output.pdf"
  exit 1
fi

# Zkus najít Chrome/Chromium v systému
CHROME_BIN=""
for c in google-chrome chromium chromium-browser chrome; do
  if command -v "$c" >/dev/null 2>&1; then
    CHROME_BIN="$c"
    break
  fi
done

if [[ -z "$CHROME_BIN" ]]; then
  echo "Chrome/Chromium not found. Install google-chrome or chromium."
  exit 1
fi

# Print to PDF
# --no-margins tady NEDÁVÁM, protože margin řeší @page v CSS.
"$CHROME_BIN" \
  --headless \
  --disable-gpu \
  --no-sandbox \
  --print-to-pdf="$OUT_PDF" \
  "file://$(realpath "$IN_HTML")"

echo "Generated PDF: $OUT_PDF"