#!/bin/bash

# Script to update locale identifiers in .xcstrings files
# Changes region-specific codes to language-only codes:
#   en-US → en
#   pl-PL → pl
#   de-DE → de

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
XCSTRINGS_DIR="$PROJECT_ROOT/2PASS/2PASS/Other"

FILES=(
    "Localizable.xcstrings"
    "InfoPlist.xcstrings"
)

total_replaced=0

for file in "${FILES[@]}"; do
    filepath="$XCSTRINGS_DIR/$file"

    if [[ ! -f "$filepath" ]]; then
        echo "Warning: $file not found at $filepath, skipping"
        continue
    fi

    echo "Processing: $file"

    # Count occurrences before
    replace_count=$(grep -o '"en-US"\|"pl-PL"\|"de-DE"' "$filepath" | wc -l | tr -d ' ')

    if [[ "$replace_count" -eq 0 ]]; then
        echo "  No changes needed"
        continue
    fi

    # Perform locale code replacements
    sed -i '' -e 's/"en-US"/"en"/g' -e 's/"pl-PL"/"pl"/g' -e 's/"de-DE"/"de"/g' "$filepath"

    # Verify no old codes remain
    after_replace=$(grep -o '"en-US"\|"pl-PL"\|"de-DE"' "$filepath" | wc -l | tr -d ' ')

    if [[ "$after_replace" -eq 0 ]]; then
        echo "  ✓ Replaced $replace_count occurrences"
        total_replaced=$((total_replaced + replace_count))
    else
        echo "  Error: codes still remain (replace: $after_replace)"
        exit 1
    fi
done

echo ""
echo "Done!"
echo "  Replacements: $total_replaced"
echo "    - en-US → en"
echo "    - pl-PL → pl"
echo "    - de-DE → de"
