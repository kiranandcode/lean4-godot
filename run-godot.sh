#!/bin/bash

lake build

if [[ "$(uname)" == "Darwin" ]]; then
  /Applications/Godot.app/Contents/MacOS/Godot -e .
else
  godot -e .
fi
