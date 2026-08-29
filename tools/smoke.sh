#!/bin/bash
set -e
GODOT="/workspace/tools/godot/Godot_v4.4.1-stable_linux.x86_64"
cd /workspace/wyrdling
echo "godot version:"
"$GODOT" --version
echo "import..."
"$GODOT" --headless --import --quit
echo "smoke..."
"$GODOT" --headless -s res://src/smoke/smoke_test.gd
echo "smoke exit $?"
