#!/bin/bash

# lake build

if [[ "$(uname)" == "Darwin" ]]; then
  /Applications/Godot.app/Contents/MacOS/Godot -w -e .
else
  godot -w -e .
fi
