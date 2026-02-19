#!/bin/bash

# Script to update locale identifiers in .xcstrings files
# Changes region-specific codes to language-only codes:
#   en-US → en
#   pl-PL → pl
# Removes unwanted locales:
#   de-DE (removed entirely)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
XCSTRINGS_DIR="$PROJECT_ROOT/2PASS/2PASS/Other"

FILES=(
    "Localizable.xcstrings"
    "InfoPlist.xcstrings"
)

total_replaced=0
total_removed=0

for file in "${FILES[@]}"; do
    filepath="$XCSTRINGS_DIR/$file"

    if [[ ! -f "$filepath" ]]; then
        echo "Warning: $file not found at $filepath, skipping"
        continue
    fi

    echo "Processing: $file"

    # Count occurrences before
    replace_count=$(grep -o '"en-US"\|"pl-PL"' "$filepath" | wc -l | tr -d ' ')
    remove_count=$(grep -o '"de-DE"' "$filepath" | wc -l | tr -d ' ')

    if [[ "$replace_count" -eq 0 && "$remove_count" -eq 0 ]]; then
        echo "  No changes needed"
        continue
    fi

    # Perform locale code replacements
    if [[ "$replace_count" -gt 0 ]]; then
        sed -i '' -e 's/"en-US"/"en"/g' -e 's/"pl-PL"/"pl"/g' "$filepath"
    fi

    # Remove de-DE entries using jq
    if [[ "$remove_count" -gt 0 ]]; then
        jq 'walk(if type == "object" and has("de-DE") then del(.["de-DE"]) else . end)' "$filepath" > "$filepath.tmp"
        mv "$filepath.tmp" "$filepath"
    fi

    # Verify no old codes remain
    after_replace=$(grep -o '"en-US"\|"pl-PL"' "$filepath" | wc -l | tr -d ' ')
    after_remove=$(grep -o '"de-DE"' "$filepath" | wc -l | tr -d ' ')

    if [[ "$after_replace" -eq 0 && "$after_remove" -eq 0 ]]; then
        echo "  ✓ Replaced $replace_count occurrences"
        echo "  ✓ Removed $remove_count de-DE entries"
        total_replaced=$((total_replaced + replace_count))
        total_removed=$((total_removed + remove_count))
    else
        echo "  Error: codes still remain (replace: $after_replace, remove: $after_remove)"
        exit 1
    fi
done

echo ""
echo "Done!"
echo "  Replacements: $total_replaced"
echo "    - en-US → en"
echo "    - pl-PL → pl"
echo "  Removals: $total_removed"
echo "    - de-DE (deleted)"
