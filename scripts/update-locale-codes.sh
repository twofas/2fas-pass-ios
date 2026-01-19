#!/bin/bash

# Script to update locale identifiers in Localizable.xcstrings
# Changes region-specific codes to language-only codes:
#   en-US → en
#   pl-PL → pl

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
XCSTRINGS_FILE="$PROJECT_ROOT/2PASS/2PASS/Other/Localizable.xcstrings"

if [[ ! -f "$XCSTRINGS_FILE" ]]; then
    echo "Error: Localizable.xcstrings not found at $XCSTRINGS_FILE"
    exit 1
fi

echo "Updating locale codes in: $XCSTRINGS_FILE"

# Count occurrences before
before_count=$(grep -o '"en-US"\|"pl-PL"' "$XCSTRINGS_FILE" | wc -l | tr -d ' ')
echo "Found $before_count occurrences to replace"

# Perform replacements
sed -i '' -e 's/"en-US"/"en"/g' -e 's/"pl-PL"/"pl"/g' "$XCSTRINGS_FILE"

# Verify no old codes remain
after_count=$(grep -o '"en-US"\|"pl-PL"' "$XCSTRINGS_FILE" | wc -l | tr -d ' ')

if [[ "$after_count" -eq 0 ]]; then
    echo "✓ Successfully replaced $before_count occurrences"
    echo "  - en-US → en"
    echo "  - pl-PL → pl"
else
    echo "Warning: $after_count occurrences still remain"
    exit 1
fi
