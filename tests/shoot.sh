#!/usr/bin/env bash
# Render screenshots with a real (software GL) renderer. Usage: tests/shoot.sh <out_dir> <map> <battle|menu>
cd "$(dirname "$0")/.."
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json timeout 300 xvfb-run -a -s "-screen 0 720x1280x24" godot --rendering-method mobile --resolution 540x960 \
  res://tests/screenshot.tscn -- "$1" "${2:-verdant_pass}" "${3:-battle}" 2>&1 | grep -E "saved|SCRIPT ERROR|ERROR:" | grep -v "status < 0"
