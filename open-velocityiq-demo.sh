#!/bin/bash
# ============================================================
#  VelocityIQ - The Used Car Profit Engine
#  One-click demo launcher (Linux)
#  If double-click doesn't work, run:  chmod +x open-velocityiq-demo.sh
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
xdg-open "$FILE" >/dev/null 2>&1 &

