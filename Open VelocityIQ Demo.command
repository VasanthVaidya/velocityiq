#!/bin/bash
# ============================================================
#  VelocityIQ - The Used Car Profit Engine
#  One-click demo launcher (macOS)
#  If double-click doesn't work the first time, run:
#     chmod +x "Open VelocityIQ Demo.command"
# ============================================================
DIR="$(cd "$(dirname "$0")" && pwd)"
FILE="$DIR/velocityiq.html"

if [ ! -f "$FILE" ]; then
  echo "Could not find velocityiq.html next to this launcher."
  echo "Keep both files together in the same folder."
  read -r -p "Press Enter to close..."
  exit 1
fi

echo "Launching the VelocityIQ demo in your default browser..."
open "$FILE"

