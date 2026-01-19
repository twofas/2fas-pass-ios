#!/bin/bash

# Script to update locale identifiers in .xcstrings files
# Changes region-specific codes to language-only codes:
#   en-US → en
#   pl-PL → pl

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
    before_count=$(grep -o '"en-US"\|"pl-PL"' "$filepath" | wc -l | tr -d ' ')

    if [[ "$before_count" -eq 0 ]]; then
        echo "  No changes needed"
        continue
    fi

    # Perform replacements
    sed -i '' -e 's/"en-US"/"en"/g' -e 's/"pl-PL"/"pl"/g' "$filepath"

    # Verify no old codes remain
    after_count=$(grep -o '"en-US"\|"pl-PL"' "$filepath" | wc -l | tr -d ' ')

    if [[ "$after_count" -eq 0 ]]; then
        echo "  ✓ Replaced $before_count occurrences"
        total_replaced=$((total_replaced + before_count))
    else
        echo "  Error: $after_count occurrences still remain"
        exit 1
    fi
done

echo ""
echo "Done! Total replacements: $total_replaced"
echo "  - en-US → en"
echo "  - pl-PL → pl"
