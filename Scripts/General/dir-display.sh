#!/bin/bash

# Usage: ./browse.sh [directory]
# Defaults to current directory if none given

DIR="${1:-.}"

# Check if directory exists
if [ ! -d "$DIR" ]; then
  echo "Error: '$DIR' is not a directory."
  exit 1
fi

# Resolve full path
DIR="$(realpath "$DIR")"

echo "========================================"
echo " Directory: $DIR"
echo "========================================"

# Loop through files (non-recursive)
for file in "$DIR"/*; do
  # Skip if no files found
  [ -e "$file" ] || continue

  name="$(basename "$file")"

  if [ -d "$file" ]; then
    echo ""
    echo "  [DIR]  $name/"
  elif [ -f "$file" ]; then
    echo ""
    echo "----------------------------------------"
    echo "  File: $DIR, $name"
    echo "----------------------------------------"
    cat "$file"
    echo ""
  fi
done

echo "========================================"
echo " Done."
echo "========================================"
